import { z } from 'zod';
import { distanceMeters } from '../../shared/geo.js';
import type { LiveRide, RideLifecycle } from '../rides/lifecycle.js';
import type { RidesRepo } from '../rides/repo.js';
import type { SettingsService } from '../settings/service.js';
import { type LiveClient, type LiveSocket, type TrackingHub, WS_CLOSE } from './hub.js';

const positionMessage = z.object({
  type: z.literal('position'),
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
  accuracy: z.number().min(0).max(10_000).optional(),
  speed: z.number().min(0).max(100).optional(),
  ts: z.iso.datetime(),
});

/** Une position toutes les 2 s au plus par client (docs/api.md). */
const MIN_INTERVAL_MS = 2000;
/** Trace pour les litiges : un point toutes les 30 s (docs/couts.md). */
const TRACE_INTERVAL_MS = 30_000;
/** Au-delà, une position n'est plus assez fraîche pour valider une présence. */
const FRESH_MS = 60_000;

/**
 * Suivi en direct (architecture §6) : position diffusée aux seuls participants du trajet
 * en cours ; le passager voit le conducteur, le conducteur voit les passagers pas encore
 * montés. ETA calculé sur le serveur sans appel d'itinéraire (docs/couts.md).
 */
export class TrackingService {
  private readonly state = new Map<string, LiveRide>();
  private readonly lastTrace = new Map<string, number>();

  constructor(
    private readonly hub: TrackingHub,
    private readonly lifecycle: RideLifecycle,
    private readonly repo: RidesRepo,
    private readonly settings: SettingsService,
    private readonly now: () => number = Date.now,
  ) {}

  /** L'état d'un trajet a changé (départ, montée, présence, clôture) : relu au besoin. */
  invalidate(rideId: string): void {
    this.state.delete(rideId);
  }

  private async live(rideId: string): Promise<LiveRide | null> {
    const cached = this.state.get(rideId);
    if (cached) return cached;
    const live = await this.lifecycle.live(rideId);
    if (live) this.state.set(rideId, live);
    return live;
  }

  /** Connexion : participant accepté d'un trajet en cours, sinon fermeture avec un code. */
  async connect(rideId: string, userId: string, socket: LiveSocket): Promise<LiveClient | null> {
    try {
      await this.lifecycle.participant(userId, rideId);
    } catch {
      socket.close(WS_CLOSE.forbidden, 'forbidden');
      return null;
    }
    const live = await this.live(rideId);
    if (!live) {
      socket.close(WS_CLOSE.notStarted, 'ride_not_in_progress');
      return null;
    }
    const client: LiveClient = { userId, socket, lastPositionAt: 0 };
    this.hub.join(rideId, client);
    // Abonné : le client sait qu'il recevra désormais les positions.
    socket.send(JSON.stringify({ type: 'ready', role: userId === live.driverId ? 'driver' : 'passenger' }));
    // Dernière position connue du conducteur, tout de suite (« dernière position connue »).
    const driver = this.hub.position(rideId, live.driverId);
    if (driver && userId !== live.driverId) {
      socket.send(JSON.stringify({ type: 'position', userId: live.driverId, lat: driver.lat, lon: driver.lon, ts: driver.ts.toISOString() }));
    }
    return client;
  }

  disconnect(rideId: string, client: LiveClient): void {
    this.hub.leave(rideId, client);
  }

  async onMessage(rideId: string, client: LiveClient, raw: string): Promise<void> {
    let data: unknown;
    try {
      data = JSON.parse(raw);
    } catch {
      return;
    }
    const parsed = positionMessage.safeParse(data);
    if (!parsed.success) return;
    const now = this.now();
    if (now - client.lastPositionAt < MIN_INTERVAL_MS) return;
    client.lastPositionAt = now;

    const live = await this.live(rideId);
    if (!live) return;
    const { lat, lon } = parsed.data;
    const ts = new Date(parsed.data.ts);
    const userId = client.userId;
    this.hub.setPosition(rideId, userId, { lat, lon, ts, receivedAt: now });

    const traceKey = `${rideId}:${userId}`;
    if (now - (this.lastTrace.get(traceKey) ?? 0) >= TRACE_INTERVAL_MS) {
      this.lastTrace.set(traceKey, now);
      await this.repo.insertTrace(rideId, userId, ts, { lat, lon });
    }

    const message = { type: 'position', userId, lat, lon, ts: ts.toISOString() };
    if (userId === live.driverId) {
      // Le passager voit le conducteur arriver ; ETA par arrêt restant.
      this.hub.send(rideId, message, (u) => u !== userId);
      await this.sendEtas(live, { lat, lon }, ts);
    } else {
      const me = live.passengers.find((p) => p.userId === userId);
      if (me && !me.pickedUp) this.hub.send(rideId, message, (u) => u === live.driverId);
    }
    await this.checkPresence(live, userId, now);
    if (userId === live.driverId) await this.checkArrival(live, { lat, lon });
  }

  private async sendEtas(live: LiveRide, driver: { lat: number; lon: number }, at: Date): Promise<void> {
    const roadFactor = await this.settings.get('matching.roadFactor');
    const speed = ((await this.settings.get('matching.avgSpeedKmh')) * 1000) / 3600;
    for (const p of live.passengers.filter((x) => !x.pickedUp)) {
      const seconds = (distanceMeters(driver, p.point) * roadFactor) / speed;
      const eta = new Date(at.getTime() + seconds * 1000).toISOString();
      this.hub.send(live.rideId, { type: 'eta', userId: p.userId, eta }, (u) => u === p.userId || u === live.driverId);
    }
  }

  /** Présence : passager et conducteur proches, positions fraîches. */
  private async checkPresence(live: LiveRide, sender: string, now: number): Promise<void> {
    const radius = await this.settings.get('tracking.presenceRadiusMeters');
    const driver = this.hub.position(live.rideId, live.driverId);
    if (!driver || now - driver.receivedAt > FRESH_MS) return;
    const candidates = live.passengers.filter((p) => !p.validated && (sender === live.driverId || p.userId === sender));
    for (const p of candidates) {
      const pos = this.hub.position(live.rideId, p.userId);
      if (!pos || now - pos.receivedAt > FRESH_MS || distanceMeters(pos, driver) > radius) continue;
      p.validated = true;
      await this.lifecycle.validatePresence(live.rideId, p.userId);
    }
  }

  /** Arrivée détectée : clôture automatique (cahier §9). */
  private async checkArrival(live: LiveRide, driver: { lat: number; lon: number }): Promise<void> {
    const radius = await this.settings.get('tracking.arrivalRadiusMeters');
    if (distanceMeters(driver, live.destination) > radius) return;
    // Pas de clôture tant qu'un passager attend encore d'être pris.
    if (live.passengers.some((p) => !p.pickedUp && !p.validated)) return;
    await this.lifecycle.finish(live.rideId, null);
  }
}
