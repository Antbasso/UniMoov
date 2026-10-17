import { AppError } from '../../shared/errors.js';
import { distanceMeters, type LatLon } from '../../shared/geo.js';
import { navigationLinks, SUPPORTS_MULTI_STOP } from '../navigation/links.js';
import type { WalletService } from '../payments/service.js';
import type { SettingsService } from '../settings/service.js';
import { PRESENCE_FRESH_MS, type TrackingHub } from '../tracking/hub.js';
import { isAccepted, type Member, pickupOf, type RideInfo, type RidesRepo } from './repo.js';
import type { RidesService } from './service.js';
import type { TrustService } from '../trust/service.js';

/** Trajet en cours vu par le suivi en direct (mis en cache par le service de suivi). */
export interface LiveRide {
  rideId: string;
  driverId: string;
  /** Campus (aller) ou domicile du conducteur (retour). */
  destination: LatLon;
  passengers: { userId: string; point: LatLon; pickedUp: boolean; validated: boolean }[];
}

/**
 * Cycle de vie d'un trajet confirmé (cahier §9, §15) : départ, montée, validation de
 * présence (déclenche le paiement du passager), clôture (prix final, retenues libérées).
 */
export class RideLifecycle {
  constructor(
    private readonly repo: RidesRepo,
    private readonly rides: RidesService,
    private readonly wallet: WalletService,
    private readonly hub: TrackingHub,
    private readonly settings: SettingsService,
    private readonly clock: () => Date,
    /** Appelé quand l'état d'un trajet en cours change (cache du suivi à rafraîchir). */
    private readonly onLiveChanged: (rideId: string) => void = () => undefined,
    /** Score de fiabilité : trajet mené à bien ou absence, dans la transaction de clôture. */
    private readonly trust?: Pick<TrustService, 'onRideFinished'>,
  ) {}

  private async load(rideId: string) {
    const ride = await this.repo.ride(rideId);
    if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
    return { ride, members: await this.repo.members(rideId) };
  }

  private driverOf(ride: RideInfo, members: Member[], userId: string): void {
    const me = members.find((m) => m.userId === userId && isAccepted(m));
    if (!me) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
    if (me.role !== 'driver' || ride.driverId !== userId) {
      throw new AppError(403, 'forbidden', 'Réservé au conducteur de ce trajet');
    }
  }

  /** Participant accepté (403 sinon) ; renvoie son rôle. */
  async participant(userId: string, rideId: string): Promise<{ ride: RideInfo; members: Member[]; me: Member }> {
    const { ride, members } = await this.load(rideId);
    const me = members.find((m) => m.userId === userId && isAccepted(m));
    if (!me) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
    return { ride, members, me };
  }

  /** État utile au suivi en direct, ou `null` si le trajet n'est pas en cours. */
  async live(rideId: string): Promise<LiveRide | null> {
    const ride = await this.repo.ride(rideId);
    if (!ride || ride.status !== 'in_progress') return null;
    const members = await this.repo.members(rideId);
    const driver = members.find((m) => m.role === 'driver');
    if (!driver?.home) return null;
    return {
      rideId,
      driverId: ride.driverId,
      destination: ride.direction === 'to_campus' ? { lat: ride.campus.lat, lon: ride.campus.lon } : driver.home,
      passengers: members
        .filter((m) => m.role === 'passenger' && isAccepted(m))
        .flatMap((m) => {
          const pickup = pickupOf(m);
          return pickup
            ? [{ userId: m.userId, point: pickup.point, pickedUp: m.status === 'picked_up', validated: m.presenceValidatedAt !== null }]
            : [];
        }),
    };
  }

  /** Départ déclaré par le conducteur : suivi ouvert, retenue du prix estimé sur chaque passager. */
  async start(userId: string, rideId: string): Promise<void> {
    const { ride, members } = await this.load(rideId);
    this.driverOf(ride, members, userId);
    if (ride.status === 'in_progress') return;
    if (ride.status !== 'confirmed') throw new AppError(409, 'ride_not_confirmed', "Ce trajet n'est pas confirmé");
    const window = await this.settings.get('rides.startWindowMinutes');
    const staleHours = await this.settings.get('rides.staleAfterHours');
    const now = this.clock().getTime();
    if (now < ride.targetTime.getTime() - window * 60_000) {
      throw new AppError(409, 'too_early', 'Trop tôt pour démarrer ce trajet');
    }
    if (now > ride.targetTime.getTime() + staleHours * 3_600_000) {
      throw new AppError(409, 'too_late', 'Ce trajet est passé');
    }
    const started = await this.repo.transaction(async (tx) => {
      const current = await this.repo.ride(rideId, tx, true);
      if (current?.status === 'in_progress') return false;
      // Relu sous le verrou : une annulation simultanée a pu retirer un passager ou rouvrir le trajet.
      if (current?.status !== 'confirmed') throw new AppError(409, 'ride_not_confirmed', "Ce trajet n'est pas confirmé");
      const passengers = (await this.repo.members(rideId, tx)).filter((m) => m.role === 'passenger' && isAccepted(m));
      const price = await this.rides.estimate(current, current.distanceM, passengers.length + 1);
      await this.repo.setRideStatus(rideId, 'in_progress', { startedAt: this.clock() }, tx);
      // Demandes de place restées sans réponse : on ne monte pas en route.
      await this.repo.declinePendingRequests(rideId, tx);
      // Tous les portefeuilles d'un coup, dans l'ordre des identifiants : pas d'interblocage.
      await this.wallet.lockWallets([ride.driverId, ...passengers.map((p) => p.userId)], tx);
      for (const p of passengers) {
        await this.wallet.holdForRide(
          {
            rideId,
            passengerId: p.userId,
            driverId: ride.driverId,
            shareCents: price?.shareCents ?? 0,
            commissionCents: price ? price.commissionCents : 0,
          },
          tx,
        );
      }
      return true;
    });
    if (!started) return;
    this.onLiveChanged(rideId);
    this.hub.send(rideId, { type: 'ride_status', status: 'in_progress' });
  }

  /** « Monté » : signalé par le conducteur ; l'arrêt sort de la navigation. */
  async pickedUp(userId: string, rideId: string, passengerId: string): Promise<void> {
    const { ride, members } = await this.load(rideId);
    this.driverOf(ride, members, userId);
    if (ride.status !== 'in_progress') throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
    const passenger = members.find((m) => m.userId === passengerId && m.role === 'passenger' && isAccepted(m));
    if (!passenger) throw new AppError(404, 'not_found', 'Ressource introuvable');
    // Sous le verrou du trajet : une clôture simultanée n'est pas écrasée.
    const done = await this.repo.transaction(async (tx) => {
      if ((await this.repo.ride(rideId, tx, true))?.status !== 'in_progress') return false;
      await this.repo.setParticipant(rideId, passengerId, { status: 'picked_up', pickedUpAt: this.clock() }, tx);
      return true;
    });
    if (!done) throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
    this.onLiveChanged(rideId);
    this.hub.send(rideId, { type: 'stop_picked_up', userId: passengerId });
  }

  /**
   * Validation de présence (cahier §9) : les deux téléphones sont proches l'un de l'autre
   * (rayon `tracking.presenceRadiusMeters`). Elle déclenche le paiement du passager.
   */
  async validatePresence(rideId: string, passengerId: string): Promise<'paid' | 'failed' | 'already'> {
    const ride = await this.repo.ride(rideId);
    if (ride?.status !== 'in_progress') throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
    const outcome = await this.repo.transaction(async (tx) => {
      const locked = await this.repo.ride(rideId, tx, true);
      if (locked?.status !== 'in_progress') return 'already' as const;
      const me = (await this.repo.members(rideId, tx)).find((m) => m.userId === passengerId);
      if (!me || me.role !== 'passenger' || !isAccepted(me)) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
      if (me.presenceValidatedAt) return 'already' as const;
      const now = this.clock();
      await this.repo.setParticipant(rideId, passengerId, { presenceValidatedAt: now }, tx);
      return this.wallet.chargeForRide({ rideId, passengerId, driverId: ride.driverId, now }, tx);
    });
    if (outcome !== 'already') {
      this.onLiveChanged(rideId);
      this.hub.send(rideId, { type: 'presence_validated', userId: passengerId, payment: outcome }, (u) =>
        [passengerId, ride.driverId].includes(u),
      );
    }
    return outcome;
  }

  /** Demande explicite du passager : les dernières positions connues doivent être proches. */
  async requestPresence(userId: string, rideId: string): Promise<'paid' | 'failed' | 'already'> {
    const { ride, me } = await this.participant(userId, rideId);
    if (me.role !== 'passenger') throw new AppError(403, 'forbidden', 'Réservé aux passagers');
    if (ride.status !== 'in_progress') throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
    const mine = this.hub.position(rideId, userId);
    const driver = this.hub.position(rideId, ride.driverId);
    const radius = await this.settings.get('tracking.presenceRadiusMeters');
    const now = this.clock().getTime();
    // Mêmes règles que la validation automatique : positions récentes et proches.
    const fresh = (p: { receivedAt: number } | undefined) => p !== undefined && now - p.receivedAt <= PRESENCE_FRESH_MS;
    // Position du conducteur jugée invraisemblable (saut impossible) : pas de validation.
    if (!mine || !driver || !driver.trusted || !fresh(mine) || !fresh(driver) || distanceMeters(mine, driver) > radius) {
      throw new AppError(409, 'presence_not_confirmed', 'Ton téléphone et celui du conducteur doivent être proches');
    }
    return this.validatePresence(rideId, userId);
  }

  /**
   * Clôture manuelle (conducteur seulement) ou automatique à l'arrivée et pour un trajet oublié :
   * prix final, retenues des absents libérées, suivi fermé. Idempotente.
   */
  async finish(rideId: string, byUserId: string | null): Promise<void> {
    if (byUserId) {
      const { ride, members } = await this.load(rideId);
      if (ride.status === 'completed' && members.some((m) => m.userId === byUserId && isAccepted(m))) return;
      // Un passager ne clôt pas : il ferait compter absents ceux qui n'étaient pas encore montés.
      this.driverOf(ride, members, byUserId);
      if (ride.status === 'completed') return;
      if (ride.status !== 'in_progress') throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
    }
    const closed = await this.repo.transaction(async (tx) => {
      const ride = await this.repo.ride(rideId, tx, true);
      if (ride?.status !== 'in_progress') return false;
      const members = await this.repo.members(rideId, tx);
      const present = members.filter((m) => m.role === 'passenger' && m.presenceValidatedAt);
      const now = this.clock();
      const missing = members.filter((m) => m.role === 'passenger' && isAccepted(m) && !m.presenceValidatedAt);
      // Clôture avant l'heure de passage d'un passager ni pris ni monté : le conducteur n'est pas
      // allé jusqu'à lui ; ce n'est pas une absence (pas de pénalité).
      const notReached = missing.filter((m) => m.status === 'accepted' && m.eta !== null && m.eta > now);
      const noShow = missing.filter((m) => !notReached.includes(m));
      const price = await this.rides.estimate(ride, ride.distanceM, present.length + 1);
      await this.repo.setRideStatus(rideId, 'completed', { endedAt: now, finalTotalCostCents: price?.totalCostCents ?? null }, tx);
      await this.wallet.releaseRemaining(rideId, tx);
      // Absence constatée : présence non validée par proximité (cahier §9).
      for (const absent of noShow) {
        await this.repo.setParticipant(rideId, absent.userId, { status: 'absent' }, tx);
      }
      for (const skipped of notReached) {
        await this.repo.setParticipant(rideId, skipped.userId, { status: 'cancelled', cancelledAt: now }, tx);
      }
      await this.trust?.onRideFinished(
        rideId,
        { completed: [ride.driverId, ...present.map((m) => m.userId)], noShow: noShow.map((m) => m.userId) },
        tx,
      );
      return true;
    });
    if (!closed) return;
    this.hub.send(rideId, { type: 'ride_status', status: 'completed' });
    this.hub.close(rideId);
    this.onLiveChanged(rideId);
  }

  /** Conducteur seulement : arrêts restants dans l'ordre et liens GPS prêts à ouvrir. */
  async navigation(userId: string, rideId: string) {
    const { ride, members } = await this.load(rideId);
    this.driverOf(ride, members, userId);
    if (ride.status !== 'confirmed' && ride.status !== 'in_progress') {
      throw new AppError(409, 'ride_not_confirmed', "Ce trajet n'est pas confirmé");
    }
    const view = await this.rides.get(userId, rideId);
    // Passagers dans l'ordre, puis la destination : campus (aller) ou domicile du conducteur (retour).
    const ordered = [...view.stops.filter((s) => s.kind === 'passenger'), view.stops.at(-1)!];
    const remaining = ordered.filter((s) => !s.pickedUp);
    return {
      stops: ordered.map((s, i) => ({
        order: i + 1,
        kind: s.kind === 'passenger' ? ('passenger' as const) : ('destination' as const),
        userId: s.userId,
        firstName: s.firstName,
        label: s.label,
        lat: s.lat,
        lon: s.lon,
        eta: s.eta,
        pickedUp: s.pickedUp,
      })),
      links: navigationLinks(remaining.length > 0 ? remaining : ordered.slice(-1)),
      supportsMultiStop: { googleMaps: SUPPORTS_MULTI_STOP.google_maps, appleMaps: SUPPORTS_MULTI_STOP.apple_maps, waze: SUPPORTS_MULTI_STOP.waze },
    };
  }

  /** Trajets restés « en cours » bien après l'heure prévue (oubli, téléphone éteint) : clôturés. */
  async closeStale(): Promise<number> {
    const hours = await this.settings.get('rides.staleAfterHours');
    const ids = await this.repo.staleInProgress(new Date(this.clock().getTime() - hours * 3_600_000));
    for (const id of ids) await this.finish(id, null);
    return ids.length;
  }

  async purgeTraces(): Promise<number> {
    const days = await this.settings.get('tracking.traceRetentionDays');
    return this.repo.purgeTraces(new Date(this.clock().getTime() - days * 86_400_000));
  }
}
