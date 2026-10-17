import { z } from 'zod';
import { distanceMeters } from '../../shared/geo.js';
import type { LiveRide, RideLifecycle } from '../rides/lifecycle.js';
import type { RidesRepo } from '../rides/repo.js';
import type { SettingsService } from '../settings/service.js';
import { type LiveClient, type LiveSocket, PRESENCE_FRESH_MS, type TrackingHub, WS_CLOSE } from './hub.js';

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
/**
 * Vraisemblance (décision de l'équipe contre l'imitation de position) : une position n'est
 * crue que si on a pu l'atteindre depuis la dernière position crue à 144 km/h de moyenne au
 * plus. Un téléphone qui « apparaît » ailleurs n'est cru qu'après le temps du vrai trajet ;
 * un point GPS aberrant isolé n'efface pas la suite. Sous 500 m, l'écart est mis sur le
 * compte de l'imprécision du GPS.
 */
const MAX_SPEED_MPS = 40;
const JUMP_TOLERANCE_M = 500;
/** Présence : téléphones proches pendant au moins ce temps (pas un simple point recopié). */
export const PRESENCE_DWELL_MS = 15_000;

/**
 * Suivi en direct (architecture §6) : position diffusée aux seuls participants du trajet
 * en cours ; le passager voit le conducteur, le conducteur voit les passagers pas encore
 * montés. ETA calculé sur le serveur sans appel d'itinéraire (docs/couts.md).
 */
export class TrackingService {
  private readonly state = new Map<string, LiveRide>();
  private readonly lastTrace = new Map<string, number>();
  private readonly anchor = new Map<string, { lat: number; lon: number; at: number }>();
  private readonly nearSince = new Map<string, number>();
  private readonly nearMisses = new Map<string, number>();

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
    // Trajet clôturé seulement (pas une salle vide un instant) : plus rien à garder.
    if (this.hub.isClosed(rideId)) {
      for (const map of [this.lastTrace, this.anchor, this.nearSince, this.nearMisses]) {
        for (const key of map.keys()) if (key.startsWith(`${rideId}:`)) map.delete(key);
      }
    }
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
    // Heure du serveur : le client ne choisit ni l'horodatage de la trace ni sa durée de conservation.
    const ts = new Date(now);
    const userId = client.userId;
    const key = `${rideId}:${userId}`;
    // Conducteur sans position crue : référence = son point de départ à l'heure du départ (sa
    // toute première position n'est pas crue d'office, sinon il « apparaît » chez un passager).
    const anchor =
      this.anchor.get(key) ??
      (userId === live.driverId ? { ...live.origin, at: live.startedAt } : undefined);
    const meters = anchor ? distanceMeters(anchor, { lat, lon }) : 0;
    const trusted = !anchor || meters <= JUMP_TOLERANCE_M || meters / Math.max((now - anchor.at) / 1000, 1) <= MAX_SPEED_MPS;
    if (trusted) this.anchor.set(key, { lat, lon, at: now });
    this.hub.setPosition(rideId, userId, { lat, lon, ts, receivedAt: now, trusted });

    if (now - (this.lastTrace.get(key) ?? 0) >= TRACE_INTERVAL_MS) {
      this.lastTrace.set(key, now);
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

  /**
   * Présence : déclenchée par la position du téléphone du passager seulement (le conducteur,
   * qui est payé, ne peut pas la provoquer en recopiant la position reçue), proche d'une
   * position fiable et fraîche du conducteur, pendant au moins `PRESENCE_DWELL_MS`.
   */
  private async checkPresence(live: LiveRide, sender: string, now: number): Promise<void> {
    const p = live.passengers.find((x) => x.userId === sender && !x.validated);
    if (!p) return;
    const key = `${live.rideId}:${p.userId}`;
    const radius = await this.settings.get('tracking.presenceRadiusMeters');
    const driver = this.hub.position(live.rideId, live.driverId);
    const pos = this.hub.position(live.rideId, p.userId);
    const near =
      driver !== undefined &&
      pos !== undefined &&
      driver.trusted &&
      now - driver.receivedAt <= PRESENCE_FRESH_MS &&
      distanceMeters(pos, driver) <= radius;
    if (!near) {
      // Une mesure isolée hors du rayon (GPS en mouvement, décalage entre les deux téléphones)
      // n'efface pas la co-présence ; deux de suite, si.
      const misses = (this.nearMisses.get(key) ?? 0) + 1;
      this.nearMisses.set(key, misses);
      if (misses >= 2) this.nearSince.delete(key);
      return;
    }
    this.nearMisses.delete(key);
    const since = this.nearSince.get(key);
    if (since === undefined) {
      this.nearSince.set(key, now);
      return;
    }
    if (now - since < PRESENCE_DWELL_MS) return;
    this.nearSince.delete(key);
    p.validated = true;
    await this.lifecycle.validatePresence(live.rideId, p.userId);
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
