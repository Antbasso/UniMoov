import type { Notifier } from '../../shared/notifications/notifier.js';
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
  /** Point de départ du conducteur et heure du départ : première référence de vraisemblance. */
  origin: LatLon;
  startedAt: number;
  /**
   * Passagers acceptés : point de prise en charge, destination (campus à l'aller, point de
   * dépose au retour), monté, présence validée, arrivé, trajet terminé de son côté.
   */
  passengers: {
    userId: string;
    point: LatLon;
    destination: LatLon;
    pickedUp: boolean;
    validated: boolean;
    arrived: boolean;
    ended: boolean;
  }[];
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
    private readonly notifier?: Notifier,
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
      origin: ride.direction === 'to_campus' ? driver.home : { lat: ride.campus.lat, lon: ride.campus.lon },
      startedAt: (ride.startedAt ?? this.clock()).getTime(),
      passengers: members
        .filter((m) => m.role === 'passenger' && isAccepted(m))
        .flatMap((m) => {
          const pickup = pickupOf(m);
          return pickup
            ? [
                {
                  userId: m.userId,
                  point: pickup.point,
                  destination: ride.direction === 'to_campus' ? { lat: ride.campus.lat, lon: ride.campus.lon } : pickup.point,
                  pickedUp: m.status === 'picked_up',
                  validated: m.presenceValidatedAt !== null,
                  arrived: m.arrivedAt !== null,
                  ended: m.endedAt !== null,
                },
              ]
            : [];
        }),
    };
  }

  /**
   * Départ déclaré par le conducteur : suivi ouvert, prix maximal retenu sur chaque passager
   * (s'il était seul présent). Un passager dont le solde ne le couvre pas ne voyage pas : sa
   * place est annulée et il est prévenu (décision du 17/10/2026).
   */
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
    const maxPrices = new Map<string, number>();
    for (const m of members.filter((x) => x.role === 'passenger' && isAccepted(x))) {
      maxPrices.set(m.userId, (await this.rides.maxPassengerPrice(rideId, m.userId)) ?? 0);
    }
    let unanswered: string[] = [];
    const unfunded: string[] = [];
    const started = await this.repo.transaction(async (tx) => {
      const current = await this.repo.ride(rideId, tx, true);
      if (current?.status === 'in_progress') return false;
      // Relu sous le verrou : une annulation simultanée a pu retirer un passager ou rouvrir le trajet.
      if (current?.status !== 'confirmed') throw new AppError(409, 'ride_not_confirmed', "Ce trajet n'est pas confirmé");
      const passengers = (await this.repo.members(rideId, tx)).filter((m) => m.role === 'passenger' && isAccepted(m));
      await this.repo.setRideStatus(rideId, 'in_progress', { startedAt: this.clock() }, tx);
      // Demandes de place restées sans réponse : on ne monte pas en route.
      unanswered = await this.repo.declinePendingRequests(rideId, tx);
      // Tous les portefeuilles d'un coup, dans l'ordre des identifiants : pas d'interblocage.
      await this.wallet.lockWallets([ride.driverId, ...passengers.map((p) => p.userId)], tx);
      for (const p of passengers) {
        const funded = await this.wallet.holdForRide(
          { rideId, passengerId: p.userId, driverId: ride.driverId, maxCents: maxPrices.get(p.userId) ?? 0 },
          tx,
        );
        if (!funded) {
          await this.repo.setParticipant(rideId, p.userId, { status: 'cancelled', cancelledAt: this.clock() }, tx);
          unfunded.push(p.userId);
        }
      }
      return true;
    });
    if (!started) return;
    if (unanswered.length > 0) {
      await this.notifier?.notify(unanswered, { type: 'request_answered', rideId, approved: false }).catch(() => undefined);
    }
    if (unfunded.length > 0) {
      await this.notifier?.notify(unfunded, { type: 'payment_required', rideId }).catch(() => undefined);
      // Leurs détours ne doivent pas renchérir le prix des autres.
      await this.rides.replanStarted(rideId).catch(() => undefined);
    }
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
   * (rayon `tracking.presenceRadiusMeters`). Le passager est compté présent ; il paiera à la
   * clôture, s'il arrive à destination.
   */
  async validatePresence(rideId: string, passengerId: string): Promise<'validated' | 'already'> {
    const ride = await this.repo.ride(rideId);
    if (ride?.status !== 'in_progress') throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
    const outcome = await this.repo.transaction(async (tx) => {
      const locked = await this.repo.ride(rideId, tx, true);
      if (locked?.status !== 'in_progress') return 'already' as const;
      const me = (await this.repo.members(rideId, tx)).find((m) => m.userId === passengerId);
      if (!me || me.role !== 'passenger' || !isAccepted(me)) throw new AppError(403, 'forbidden', "Tu ne fais pas partie de ce trajet");
      if (me.presenceValidatedAt || me.endedAt) return 'already' as const;
      await this.repo.setParticipant(rideId, passengerId, { presenceValidatedAt: this.clock() }, tx);
      return 'validated' as const;
    });
    if (outcome === 'validated') {
      this.onLiveChanged(rideId);
      this.hub.send(rideId, { type: 'presence_validated', userId: passengerId }, (u) => [passengerId, ride.driverId].includes(u));
    }
    return outcome;
  }

  /** Demande explicite du passager : les dernières positions connues doivent être proches. */
  async requestPresence(userId: string, rideId: string): Promise<'validated' | 'already'> {
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
   * Passager arrivé à destination (son téléphone, ou celui du conducteur, près de sa
   * destination après sa prise en charge) : son trajet est terminé, il paiera à la clôture.
   */
  async arrive(rideId: string, passengerId: string): Promise<void> {
    const done = await this.repo.transaction(async (tx) => {
      if ((await this.repo.ride(rideId, tx, true))?.status !== 'in_progress') return false;
      const me = (await this.repo.members(rideId, tx)).find((m) => m.userId === passengerId && m.role === 'passenger');
      if (!me || !isAccepted(me) || !me.presenceValidatedAt || me.endedAt) return false;
      const now = this.clock();
      await this.repo.setParticipant(rideId, passengerId, { arrivedAt: now, endedAt: now }, tx);
      return true;
    });
    if (!done) return;
    this.onLiveChanged(rideId);
    this.hub.send(rideId, { type: 'passenger_arrived', userId: passengerId });
    this.hub.dismiss(rideId, passengerId);
    await this.finishIfEveryoneDone(rideId);
  }

  /**
   * « Terminer le trajet » (cahier §9, décision du 18/10/2026). Conducteur : clôture pour tous.
   * Passager : son trajet seulement ; à bord (présence validée), sa part reste due même s'il
   * descend avant la destination prévue, comme chez les autres services de covoiturage ; un
   * problème se règle par un litige pendant le délai de signalement. Le conducteur est prévenu
   * tout de suite. Idempotent.
   */
  async finish(rideId: string, byUserId: string | null): Promise<void> {
    if (byUserId) {
      const { ride, me } = await this.participant(byUserId, rideId).catch(async (error: unknown) => {
        // Absent sur un trajet clôturé : rien à faire.
        const loaded = await this.load(rideId);
        if (loaded.ride.status === 'completed' && loaded.members.some((m) => m.userId === byUserId)) {
          return { ride: loaded.ride, me: null };
        }
        throw error;
      });
      if (ride.status === 'completed') return;
      if (ride.status !== 'in_progress') throw new AppError(409, 'ride_not_started', "Le trajet n'a pas commencé");
      if (me?.role === 'passenger') return this.leave(rideId, me.userId, ride.driverId);
    }
    await this.close(rideId);
  }

  private async leave(rideId: string, passengerId: string, driverId: string): Promise<void> {
    const early = await this.repo.transaction(async (tx) => {
      if ((await this.repo.ride(rideId, tx, true))?.status !== 'in_progress') return null;
      const me = (await this.repo.members(rideId, tx)).find((m) => m.userId === passengerId);
      if (!me || me.endedAt) return null;
      // Pas encore à bord : renoncer, c'est annuler sa place (pénalité, cahier §8), pas terminer.
      if (!me.presenceValidatedAt) {
        throw new AppError(409, 'not_on_board', "Ta présence n'est pas validée : pour renoncer, annule ta place");
      }
      await this.repo.setParticipant(rideId, passengerId, { endedAt: this.clock() }, tx);
      return me.arrivedAt === null;
    });
    if (early === null) return;
    if (early) {
      await this.notifier?.notify([driverId], { type: 'passenger_left', rideId }).catch(() => undefined);
      this.hub.send(rideId, { type: 'passenger_left', userId: passengerId }, (u) => u === driverId);
    }
    this.hub.dismiss(rideId, passengerId);
    this.onLiveChanged(rideId);
    await this.finishIfEveryoneDone(rideId);
  }

  /** Participants changés hors du cycle de vie (annulation pendant le trajet) : suivi coupé pour qui n'en fait plus partie. */
  async onParticipantsChanged(rideId: string): Promise<void> {
    if ((await this.repo.ride(rideId))?.status !== 'in_progress') return;
    for (const m of (await this.repo.members(rideId)).filter((x) => x.role === 'passenger' && !isAccepted(x))) {
      this.hub.dismiss(rideId, m.userId);
    }
    this.onLiveChanged(rideId);
  }

  /** Tous les passagers ont terminé (arrivés ou sortis) : le trajet est clos pour tous. */
  private async finishIfEveryoneDone(rideId: string): Promise<void> {
    const members = await this.repo.members(rideId);
    const passengers = members.filter((m) => m.role === 'passenger' && isAccepted(m));
    if (passengers.length > 0 && passengers.every((m) => m.endedAt !== null)) await this.close(rideId);
  }

  /** Conducteur arrivé à la destination finale : à l'aller, ses passagers présents arrivent avec lui. */
  async driverArrived(rideId: string): Promise<void> {
    const ride = await this.repo.ride(rideId);
    if (ride?.status !== 'in_progress') return;
    if (ride.direction === 'to_campus') {
      const members = await this.repo.members(rideId);
      for (const m of members.filter((x) => x.role === 'passenger' && isAccepted(x) && x.presenceValidatedAt && !x.endedAt)) {
        await this.arrive(rideId, m.userId);
      }
    }
    await this.close(rideId);
  }

  /**
   * Clôture (conducteur, arrivée, tous terminés, ou trajet oublié) : prix final au prorata de
   * la distance à bord (chaque portion partagée entre les présents, conducteur compris), payé
   * par chaque passager présent (pris en charge,
   * arrivé ou descendu avant) ; les autres retenues sont libérées ; absences constatées ; suivi
   * fermé. La part du conducteur attend le délai de signalement. Idempotente.
   */
  private async close(rideId: string): Promise<void> {
    const closed = await this.repo.transaction(async (tx) => {
      const ride = await this.repo.ride(rideId, tx, true);
      if (ride?.status !== 'in_progress') return null;
      const members = await this.repo.members(rideId, tx);
      const present = members.filter((m) => m.role === 'passenger' && isAccepted(m) && m.presenceValidatedAt);
      const now = this.clock();
      const missing = members.filter((m) => m.role === 'passenger' && isAccepted(m) && !m.presenceValidatedAt);
      // Clôture avant l'heure de prise en charge d'un passager ni pris ni monté, qui n'est pas
      // parti de lui-même : le conducteur n'est pas allé jusqu'à lui ; ce n'est pas une absence.
      // Prise en charge : heure de passage à l'aller ; au retour, départ du campus.
      const pickupTime = (m: (typeof missing)[number]) => (ride.direction === 'to_campus' ? m.eta : ride.targetTime);
      const notReached = missing.filter(
        (m) => m.status === 'accepted' && !m.endedAt && (pickupTime(m)?.getTime() ?? 0) > now.getTime(),
      );
      const noShow = missing.filter((m) => !notReached.includes(m));
      // Prix final : chaque portion de route partagée entre les présents à bord (prorata).
      const price = await this.rides.shares(ride, await this.rides.billingDistance(rideId), present);
      await this.repo.setRideStatus(rideId, 'completed', { endedAt: now, finalTotalCostCents: price?.totalCostCents ?? null }, tx);
      // Paiement de chaque passager pris en charge, au prix final partagé entre les présents.
      for (const p of present) {
        await this.wallet.chargeForRide(
          {
            rideId,
            passengerId: p.userId,
            driverId: ride.driverId,
            shareCents: price?.byUser.get(p.userId) ?? 0,
            commissionCents: price?.commissionCents ?? 0,
            now,
          },
          tx,
        );
      }
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
        // Conducteur qui a laissé un passager en route : trajet non compté comme mené à bien.
        {
          completed: [...(notReached.length === 0 ? [ride.driverId] : []), ...present.map((m) => m.userId)],
          noShow: noShow.map((m) => m.userId),
        },
        tx,
      );
      return { skipped: notReached.map((m) => m.userId), toRate: present.length > 0 ? [ride.driverId, ...present.map((m) => m.userId)] : [] };
    });
    if (!closed) return;
    // Notation (cahier §7) : conducteur et passagers présents sont invités à se noter.
    if (closed.toRate.length > 0) {
      await this.notifier?.notify(closed.toRate, { type: 'rating_requested', rideId }).catch(() => undefined);
    }
    if (closed.skipped.length > 0) {
      await this.notifier?.notify(closed.skipped, { type: 'ride_cancelled', rideId, by: 'driver' }).catch(() => undefined);
    }
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
    for (const id of ids) await this.close(id);
    return ids.length;
  }

  async purgeTraces(): Promise<number> {
    const days = await this.settings.get('tracking.traceRetentionDays');
    return this.repo.purgeTraces(new Date(this.clock().getTime() - days * 86_400_000));
  }
}
