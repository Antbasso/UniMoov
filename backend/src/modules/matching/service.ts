import { AppError } from '../../shared/errors.js';
import { sectorCenter } from '../../shared/geo.js';
import { addDaysIso, isoWeekOf, parisDateOf, parisToUtc, weekDays } from '../../shared/time.js';
import { estimateRoute } from '../../shared/routing/estimate.js';
import { estimatePrice } from '../pricing/domain.js';
import { isPausedOn } from '../profile/domain.js';
import { type CancelTier, rankingCost } from '../trust/domain.js';
import type { Notifier } from '../../shared/notifications/notifier.js';
import type { SettingsService } from '../settings/service.js';
import {
  detourSeconds,
  type Direction,
  isTimeCompatible,
  type MatchParams,
  matchSlot,
  type Need,
  pickupOrder,
} from './domain.js';
import type { DbOrTx, MatchingRepo, ParticipantRow, RideRow } from './repo.js';

const DIRECTIONS: Direction[] = ['to_campus', 'from_campus'];
/** Semaines générables à l'avance (la génération du vendredi couvre la suivante). */
const MAX_WEEKS_AHEAD = 4;

const ACTIVE = (p: ParticipantRow) => p.status !== 'declined' && p.status !== 'cancelled';

/**
 * Personne vue avant acceptation mutuelle : prénom, photo, secteur approximatif, score,
 * détour (cahier §4). Ni nom de famille, ni adresse, ni coordonnées exactes.
 */
export interface PublicPerson {
  userId: string;
  firstName: string;
  photoUrl: string | null;
  sector: { lat: number; lon: number } | null;
  reliabilityScore: number;
  detourMinutes: number;
  status: string;
}

export interface ProposalView {
  id: string;
  day: string;
  direction: Direction;
  time: Date;
  role: 'driver' | 'passenger';
  myStatus: string;
  rideStatus: string;
  seatsTotal: number;
  seatsTaken: number;
  detourMinutes: number;
  driver: PublicPerson | null;
  passengers: PublicPerson[];
}

export interface JoinableRide {
  rideId: string;
  day: string;
  direction: Direction;
  time: Date;
  seatsLeft: number;
  driver: PublicPerson;
}

/** Passager supplémentaire suggéré au conducteur, avec la simulation du prix (cahier §4). */
export interface Suggestion {
  person: PublicPerson;
  /** `false` : écarté automatiquement car au-delà du détour maximal du conducteur. */
  withinDetourLimit: boolean;
  shareCents: number;
  passengerPaysCents: number;
}

export interface SuggestionsView {
  seatsLeft: number;
  /** Prix actuel par personne (estimation à vol d'oiseau, comme la simulation). */
  current: { persons: number; shareCents: number; passengerPaysCents: number } | null;
  suggestions: Suggestion[];
}

const MAX_SUGGESTIONS = 10;

const minutes = (seconds: number | null) => Math.ceil((seconds ?? 0) / 60);
/** Centre de la cellule de 500 m, arrondi : pas de fausse précision. */
const round4 = (value: number) => Math.round(value * 1e4) / 1e4;
export const publicSector = (sector: string) => {
  const center = sectorCenter(sector);
  return { lat: round4(center.lat), lon: round4(center.lon) };
};

function publicPerson(p: ParticipantRow, detourS: number | null = p.detourS): PublicPerson {
  return {
    userId: p.userId,
    firstName: p.firstName,
    photoUrl: p.photoUrl,
    sector: p.sector ? publicSector(p.sector) : null,
    reliabilityScore: p.reliability,
    detourMinutes: minutes(detourS),
    status: p.status,
  };
}

/** Pénalité d'annulation (module confiance), inscrite dans la même transaction. */
export interface CancellationPolicy {
  cancellationTier(rideTime: Date): Promise<CancelTier>;
  penalizeCancellation(userId: string, rideId: string, rideTime: Date, db: DbOrTx): Promise<CancelTier>;
}

const silentNotifier: Notifier = { notify: () => Promise.resolve() };

export class MatchingService {
  constructor(
    private readonly repo: MatchingRepo,
    private readonly settings: SettingsService,
    private readonly clock: () => Date,
    /** Arrêts d'un trajet confirmé modifiés : nouveau plan (tracé, heures, prix). */
    private readonly onRideChanged: (rideId: string) => Promise<void> = () => Promise.resolve(),
    private readonly policy?: CancellationPolicy,
    private readonly notifier: Notifier = silentNotifier,
    /**
     * Solde du passager suffisant pour le prix maximal du trajet (`402 insufficient_funds`
     * sinon) : pas de trajet avec un solde nul ou trop faible (décision du 17/10/2026).
     */
    private readonly requireFunds: (userId: string, rideId: string, detourS: number | null) => Promise<void> = () =>
      Promise.resolve(),
  ) {}

  private today(): string {
    return parisDateOf(this.clock());
  }

  private async params(campus: { lat: number; lon: number }): Promise<MatchParams> {
    return {
      campus,
      roadFactor: await this.settings.get('matching.roadFactor'),
      avgSpeedKmh: await this.settings.get('matching.avgSpeedKmh'),
      arrivalWindowMinutes: await this.settings.get('matching.arrivalWindowMinutes'),
      reliabilityWeightSeconds: await this.settings.get('matching.reliabilityWeightSeconds'),
    };
  }

  /**
   * Recalcule les propositions ouvertes d'un jour (les trajets où quelqu'un a accepté sont
   * conservés). Le passé n'est jamais recalculé.
   */
  async regenerateDay(day: string): Promise<void> {
    if (day < this.today()) return;
    await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, day);
      const rows = await this.repo.needsForDay(day, tx);
      const pauses = await this.repo.pausesFor(
        rows.map((r) => r.userId),
        tx,
      );
      const available = rows.filter((r) => !isPausedOn(pauses.get(r.userId) ?? [], day));
      const campuses = [...new Set(available.map((r) => r.campusId))];

      for (const direction of DIRECTIONS) {
        await this.repo.deleteOpenRides(day, direction, tx);
        const locked = await this.repo.lockedUsers(day, direction, tx);
        const declines = await this.repo.declines(day, direction, tx);
        for (const campusId of campuses) {
          const needs: Need[] = available
            .filter((r) => r.campusId === campusId && !locked.has(r.userId))
            .map((r) => ({
              userId: r.userId,
              home: { lat: r.lat, lon: r.lon },
              time: direction === 'to_campus' ? r.start : r.end,
              roleMode: r.roleMode,
              vehicle:
                r.seats !== null && r.maxDetourMinutes !== null
                  ? { seats: r.seats, maxDetourMinutes: r.maxDetourMinutes }
                  : null,
              reliability: r.reliability,
              drivenRecently: r.drivenRecently,
            }));
          const params = await this.params(await this.repo.campusLocation(campusId, tx));
          const { rides } = matchSlot(needs, direction, params, (d, p) => declines.has(`${d}|${p}`));
          for (const planned of rides) await this.repo.insertRide(planned, { day, direction, campusId }, tx);
        }
      }
    });
  }

  /** Génération hebdomadaire, faite une seule fois par semaine (puis relances ciblées). */
  async ensureWeek(week: string): Promise<void> {
    if (await this.repo.isWeekGenerated(week)) return;
    for (const day of weekDays(week)) await this.regenerateDay(day);
    await this.repo.markWeekGenerated(week, this.clock());
  }

  /** Horaire, pause ou profil modifié : propositions recalculées pour ces jours (cahier §3). */
  async onScheduleChanged(userId: string, days: readonly string[]): Promise<void> {
    const today = this.today();
    for (const day of days) {
      if (day < today) continue;
      const cancelled = await this.repo.transaction(async (tx) => {
        await this.repo.lockDay(tx, day);
        return this.repo.releaseUnconfirmed(userId, day, this.clock(), tx);
      });
      for (const ride of cancelled) {
        await this.notifier.notify(ride.passengers, { type: 'ride_cancelled', rideId: ride.rideId, by: 'driver' }).catch(() => undefined);
      }
      if (await this.repo.isWeekGenerated(isoWeekOf(day))) await this.regenerateDay(day);
    }
  }

  /** Profil modifié (adresse, véhicule, rôle, pause) : relance sur deux semaines. */
  async onProfileChanged(userId: string): Promise<void> {
    const today = this.today();
    await this.onScheduleChanged(
      userId,
      Array.from({ length: 14 }, (_, i) => addDaysIso(today, i)),
    );
  }

  async listProposals(userId: string, week: string): Promise<ProposalView[]> {
    // Génération seulement pour les semaines utiles : passées en lecture seule, futur borné.
    const monday = weekDays(week)[0]!;
    const today = this.today();
    if (monday > addDaysIso(today, MAX_WEEKS_AHEAD * 7)) {
      throw new AppError(400, 'week_out_of_range', 'Semaine trop lointaine');
    }
    if (addDaysIso(monday, 6) >= today) await this.ensureWeek(week);
    const days = weekDays(week);
    const rides = await this.repo.ridesForUser(userId, days[0]!, addDaysIso(days[6]!, 1));
    const participants = await this.repo.participants(rides.map((r) => r.id));
    return rides.flatMap((ride) => {
      const view = this.view(
        userId,
        ride,
        participants.filter((p) => p.rideId === ride.id),
      );
      return view ? [view] : [];
    });
  }

  private view(userId: string, ride: RideRow, parts: ParticipantRow[]): ProposalView | null {
    const me = parts.find((p) => p.userId === userId);
    if (!me) return null;
    const driver = parts.find((p) => p.role === 'driver')!;
    const passengers = parts.filter((p) => p.role === 'passenger' && ACTIVE(p));
    return {
      id: ride.id,
      day: ride.day,
      direction: ride.direction,
      time: ride.targetTime,
      role: me.role,
      myStatus: me.status,
      rideStatus: ride.status,
      seatsTotal: ride.seatsTotal,
      seatsTaken: passengers.length,
      detourMinutes: minutes(me.detourS),
      driver: me.role === 'passenger' ? publicPerson(driver, me.detourS) : null,
      passengers: me.role === 'driver' ? passengers.map((p) => publicPerson(p)) : [],
    };
  }

  private async viewFor(userId: string, rideId: string, db?: DbOrTx): Promise<ProposalView> {
    const ride = (await this.repo.findRide(rideId, db))!;
    return this.view(userId, ride, await this.repo.participants([rideId], db))!;
  }

  private assertOpen(ride: RideRow | undefined): RideRow {
    if (!ride) throw new AppError(404, 'not_found', 'Ressource introuvable');
    if (ride.day < this.today()) throw new AppError(409, 'proposal_expired', 'Cette proposition est passée');
    if (ride.status === 'cancelled') throw new AppError(409, 'proposal_cancelled', 'Cette proposition a été annulée');
    // Trajet commencé ou terminé : plus d'acceptation ni de refus (on ne monte pas en route sans payer).
    if (ride.status !== 'proposed' && ride.status !== 'confirmed') {
      throw new AppError(409, 'ride_unavailable', 'Cette voiture ne peut plus te prendre');
    }
    return ride;
  }

  /**
   * Accepter : sa propre proposition, ou une autre voiture trouvée par « voir d'autres » ou
   * la recherche (le serveur revérifie places, horaire et détour). Le trajet est confirmé
   * quand le conducteur et au moins un passager ont accepté (confirmation à deux).
   */
  async accept(userId: string, rideId: string): Promise<ProposalView> {
    // Toujours le verrou du jour avant celui du trajet (même ordre que la régénération).
    const peek = this.assertOpen(await this.repo.peekRide(rideId));
    const mine = (await this.repo.participants([rideId])).find((p) => p.userId === userId);
    if (mine?.role === 'passenger' && mine.status === 'proposed') await this.requireFunds(userId, rideId, null);
    const result = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      const parts = await this.repo.participants([rideId], tx);
      const me = parts.find((p) => p.userId === userId);

      let requested = false;
      if (me) {
        if (!ACTIVE(me)) throw new AppError(409, 'proposal_declined', 'Tu as refusé cette proposition');
        // Demande déjà envoyée : c'est au conducteur de répondre.
        if (me.status !== 'requested') await this.repo.setParticipantStatus(rideId, userId, 'accepted', tx);
      } else {
        // Sans créneau ce jour-là (trajet trouvé par la recherche) : l'heure du trajet choisi.
        const joinable = await this.joinable(userId, ride.day, ride.direction, null, tx, undefined, ride.targetTime);
        const match = joinable.find((j) => j.rideId === rideId);
        if (!match) throw new AppError(409, 'ride_unavailable', 'Cette voiture ne peut plus te prendre');
        await this.requireFunds(userId, rideId, match.driver.detourMinutes * 60);
        for (const other of await this.repo.otherActiveRides(userId, ride.day, ride.direction, rideId, tx)) {
          const otherParts = await this.repo.participants([other.ride_id], tx);
          const mine = otherParts.find((p) => p.userId === userId)!;
          if (mine.role === 'driver') throw new AppError(409, 'already_driving', 'Tu conduis déjà ce jour-là');
          if (mine.status === 'accepted') throw new AppError(409, 'already_committed', 'Tu as déjà un trajet ce jour-là');
          await this.repo.setParticipantStatus(other.ride_id, userId, 'declined', tx);
        }
        // Voiture choisie par le passager (recherche, « voir d'autres ») : le conducteur ne l'a
        // pas encore accepté, donc ni nom ni adresse échangés avant sa réponse (cahier §4).
        await this.repo.addPassenger(rideId, userId, match.driver.detourMinutes * 60, tx, 'requested');
        requested = true;
      }

      const updated = await this.repo.participants([rideId], tx);
      const driverAccepted = updated.some((p) => p.role === 'driver' && p.status === 'accepted');
      const passengerAccepted = updated.some((p) => p.role === 'passenger' && p.status === 'accepted');
      if (driverAccepted && passengerAccepted && ride.status === 'proposed') {
        await this.repo.setRideStatus(rideId, 'confirmed', tx);
      }
      // Tracé à refaire seulement si cette réponse ajoute quelqu'un d'accepté (pas pour une demande
      // en attente ni un second appui : appel d'itinéraire inutile).
      const accepting = me !== undefined && me.status === 'proposed';
      const confirmed = accepting && driverAccepted && passengerAccepted;
      if (confirmed) await this.repo.invalidatePlan(rideId, tx);
      return { view: await this.viewFor(userId, rideId, tx), confirmed, requested, driverId: ride.driverId };
    });
    // Après la transaction (appel d'itinéraire) ; en cas d'échec, le plan sera calculé à la lecture.
    if (result.confirmed) await this.onRideChanged(rideId).catch(() => undefined);
    if (result.requested) {
      await this.notifier.notify([result.driverId], { type: 'ride_requested', rideId }).catch(() => undefined);
    }
    return result.view;
  }

  /**
   * Réponse du conducteur à une demande de place (passager venu par la recherche ou « voir
   * d'autres »). Acceptée : le passager est accepté des deux côtés, le trajet peut être
   * confirmé. Refusée : la paire n'est plus reproposée ce jour-là et on lui cherche une autre voiture.
   */
  async answerRequest(driverId: string, rideId: string, passengerId: string, approve: boolean): Promise<ProposalView> {
    const peek = this.assertOpen(await this.repo.peekRide(rideId));
    const result = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      const parts = await this.repo.participants([rideId], tx);
      if (ride.driverId !== driverId) throw new AppError(403, 'forbidden', 'Réservé au conducteur');
      const request = parts.find((p) => p.userId === passengerId && p.role === 'passenger');
      if (request?.status !== 'requested') throw new AppError(404, 'not_found', 'Ressource introuvable');
      if (!approve) {
        await this.repo.setParticipantStatus(rideId, passengerId, 'declined', tx);
        await this.repo.recordDecline(passengerId, driverId, ride.day, ride.direction, tx);
        return { ride, confirmed: false };
      }
      await this.repo.setParticipantStatus(rideId, passengerId, 'accepted', tx);
      const driverAccepted = parts.some((p) => p.role === 'driver' && p.status === 'accepted');
      if (driverAccepted && ride.status === 'proposed') await this.repo.setRideStatus(rideId, 'confirmed', tx);
      if (driverAccepted) await this.repo.invalidatePlan(rideId, tx);
      return { ride, confirmed: driverAccepted };
    });
    await this.notifier.notify([passengerId], { type: 'request_answered', rideId, approved: approve }).catch(() => undefined);
    if (result.confirmed) await this.onRideChanged(rideId).catch(() => undefined);
    if (!approve) await this.rehome(passengerId, result.ride).catch(() => undefined);
    return this.viewFor(driverId, rideId);
  }

  /**
   * Refuser une proposition encore ouverte. Passager : la paire n'est plus reproposée ce
   * jour-là. Conducteur : le trajet est annulé et ses passagers sont relancés.
   * Après acceptation, c'est une annulation (`cancel`), avec pénalité.
   */
  async decline(userId: string, rideId: string): Promise<void> {
    const peek = this.assertOpen(await this.repo.peekRide(rideId));
    const ride = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      const parts = await this.repo.participants([rideId], tx);
      const me = parts.find((p) => p.userId === userId);
      if (!me) throw new AppError(404, 'not_found', 'Ressource introuvable');
      // Une demande de place encore sans réponse se retire comme une proposition.
      if (me.status !== 'proposed' && me.status !== 'requested') {
        throw new AppError(409, 'already_answered', 'Tu as déjà répondu à cette proposition');
      }
      if (me.role === 'passenger') {
        await this.repo.setParticipantStatus(rideId, userId, 'declined', tx);
        await this.repo.recordDecline(userId, ride.driverId, ride.day, ride.direction, tx);
        return null;
      }
      await this.repo.setParticipantStatus(rideId, userId, 'declined', tx);
      await this.repo.setRideStatus(rideId, 'cancelled', tx);
      await this.repo.cancelParticipants(rideId, this.clock(), tx);
      for (const p of parts.filter((x) => x.role === 'passenger')) {
        await this.repo.recordDecline(userId, p.userId, ride.day, ride.direction, tx);
      }
      return ride;
    });
    if (ride) await this.regenerateDay(ride.day);
  }

  private requirePolicy(): CancellationPolicy {
    if (!this.policy) throw new Error('Politique d’annulation non configurée');
    return this.policy;
  }

  /** Avant d'annuler : palier de pénalité si l'annulation avait lieu maintenant (cahier §8). */
  /**
   * Trajet annulable : ouvert, ou en cours pour un passager pas encore à bord (présence non
   * validée) ; une fois à bord, il termine son trajet au lieu d'annuler.
   */
  private assertCancellable(ride: RideRow | undefined, me: ParticipantRow | undefined): RideRow {
    if (ride?.status === 'in_progress' && me?.role === 'passenger' && me.status === 'accepted' && !me.presenceValidated) {
      return ride;
    }
    return this.assertOpen(ride);
  }

  async cancellation(userId: string, rideId: string): Promise<{ role: 'driver' | 'passenger'; tier: CancelTier }> {
    const found = await this.repo.findRide(rideId);
    const me = (await this.repo.participants([rideId])).find((p) => p.userId === userId);
    const ride = this.assertCancellable(found, me);
    if (!me) throw new AppError(404, 'not_found', 'Ressource introuvable');
    if (me.status !== 'accepted') throw new AppError(409, 'not_accepted', "Tu n'as pas accepté ce trajet");
    return { role: me.role, tier: await this.requirePolicy().cancellationTier(ride.targetTime) };
  }

  /**
   * Annulation après acceptation (cahier §8) : pénalité dégressive selon le délai,
   * notification immédiate des autres, recherche automatique de remplaçant. Passager : sa
   * place est proposée au meilleur passager disponible. Conducteur : le trajet est annulé
   * et chaque passager reçoit une autre voiture si possible.
   */
  async cancel(userId: string, rideId: string): Promise<{ tier: CancelTier }> {
    const policy = this.requirePolicy();
    const peek = await this.repo.peekRide(rideId);
    if (!peek) throw new AppError(404, 'not_found', 'Ressource introuvable');
    const outcome = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const found = await this.repo.findRide(rideId, tx);
      const parts = await this.repo.participants([rideId], tx);
      const me = parts.find((p) => p.userId === userId);
      // Relu sous le verrou du trajet : une validation de présence simultanée l'emporte.
      const ride = this.assertCancellable(found, me);
      const started = ride.status === 'in_progress';
      if (!me) throw new AppError(404, 'not_found', 'Ressource introuvable');
      if (me.status !== 'accepted') throw new AppError(409, 'not_accepted', "Tu n'as pas accepté ce trajet");
      const now = this.clock();
      const tier = await policy.penalizeCancellation(userId, rideId, ride.targetTime, tx);
      const others = parts.filter((p) => p.userId !== userId && p.status === 'accepted');

      if (me.role === 'passenger') {
        await this.repo.cancelParticipant(rideId, userId, now, tx);
        // Ni lui ni ce conducteur ne se revoient proposés ce jour-là.
        await this.repo.recordDecline(userId, ride.driverId, ride.day, ride.direction, tx);
        if (ride.status === 'confirmed' && !others.some((p) => p.role === 'passenger')) {
          await this.repo.setRideStatus(rideId, 'proposed', tx);
        }
        // Trajet en cours : plan figé (prix retenu), retenue libérée à la clôture.
        if (!started) await this.repo.invalidatePlan(rideId, tx);
        return { ride, tier, role: me.role, notify: others.map((p) => p.userId), freed: [] as string[], started };
      }
      await this.repo.setRideStatus(rideId, 'cancelled', tx);
      await this.repo.cancelParticipants(rideId, now, tx);
      for (const p of parts.filter((x) => x.role === 'passenger')) {
        await this.repo.recordDecline(userId, p.userId, ride.day, ride.direction, tx);
      }
      const freed = parts.filter((p) => p.role === 'passenger' && ACTIVE(p)).map((p) => p.userId);
      return { ride, tier, role: me.role, notify: others.map((p) => p.userId), freed, started };
    });

    // Après la transaction : rien de ce qui suit ne remet l'annulation en cause.
    if (outcome.notify.length > 0) {
      await this.notifier.notify(outcome.notify, { type: 'ride_cancelled', rideId, by: outcome.role }).catch(() => undefined);
    }
    if (outcome.role === 'passenger') {
      await this.onRideChanged(rideId).catch(() => undefined);
      // Voiture déjà partie : pas de remplaçant.
      if (!outcome.started) await this.proposeReplacement(rideId).catch(() => undefined);
    } else {
      await this.regenerateDay(outcome.ride.day).catch(() => undefined);
      for (const passengerId of outcome.freed) {
        await this.rehome(passengerId, outcome.ride).catch(() => undefined);
      }
    }
    return { tier: outcome.tier };
  }

  /** Place libérée : le passager suggéré le mieux placé reçoit une proposition. */
  private async proposeReplacement(rideId: string): Promise<void> {
    const peek = await this.repo.peekRide(rideId);
    if (!peek) return;
    const invited = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const ride = await this.repo.findRide(rideId, tx);
      // Heure passée : la voiture est partie, personne n'est relancé.
      if (!ride || ride.targetTime <= this.clock() || (ride.status !== 'proposed' && ride.status !== 'confirmed')) return null;
      const view = await this.suggestionsFor(ride, tx);
      const pick = view.seatsLeft > 0 ? view.suggestions.find((s) => s.withinDetourLimit) : undefined;
      if (!pick) return null;
      await this.repo.addPassenger(rideId, pick.person.userId, pick.person.detourMinutes * 60, tx, 'proposed');
      return pick.person.userId;
    });
    if (invited) await this.notifier.notify([invited], { type: 'replacement_proposed', rideId });
  }

  /** Passager dont le conducteur a annulé : la meilleure autre voiture lui est proposée. */
  private async rehome(passengerId: string, cancelled: RideRow): Promise<void> {
    if (cancelled.targetTime <= this.clock()) return;
    const rideId = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, cancelled.day);
      // La régénération du jour lui a peut-être déjà trouvé une voiture : on le prévient.
      const [already] = await this.repo.otherActiveRides(passengerId, cancelled.day, cancelled.direction, cancelled.id, tx);
      if (already) return already.ride_id;
      const [best] = await this.joinable(passengerId, cancelled.day, cancelled.direction, cancelled.id, tx, undefined, cancelled.targetTime);
      if (!best) return null;
      await this.repo.addPassenger(best.rideId, passengerId, best.driver.detourMinutes * 60, tx, 'proposed');
      return best.rideId;
    });
    if (rideId) await this.notifier.notify([passengerId], { type: 'replacement_proposed', rideId });
  }

  /** « Voir d'autres propositions » : autres voitures compatibles pour le même créneau. */
  async alternatives(userId: string, rideId: string): Promise<JoinableRide[]> {
    const ride = this.assertOpen(await this.repo.findRide(rideId));
    const me = (await this.repo.participants([rideId])).find((p) => p.userId === userId);
    if (!me) throw new AppError(404, 'not_found', 'Ressource introuvable');
    if (me.role !== 'passenger') return [];
    return this.joinable(userId, ride.day, ride.direction, rideId);
  }

  /** Recherche manuelle (cahier §4), limitée par un quota quotidien. */
  async search(userId: string, query: { day: string; direction: Direction; time?: string | undefined }) {
    if (query.day < this.today()) throw new AppError(400, 'day_in_past', 'Choisis une date à venir');
    const quota = await this.settings.get('search.dailyQuota');
    if ((await this.repo.incrementSearch(userId, this.today())) > quota) {
      throw new AppError(429, 'search_quota_exceeded', 'Tu as atteint le nombre de recherches du jour');
    }
    return this.joinable(userId, query.day, query.direction, null, undefined, query.time);
  }

  /**
   * Conducteur seulement : passagers sans trajet ce jour-là qui pourraient monter, y compris
   * ceux écartés car au-delà de son détour maximal, avec la baisse de prix simulée (cahier §4).
   */
  async suggestions(userId: string, rideId: string): Promise<SuggestionsView> {
    const ride = this.assertOpen(await this.repo.findRide(rideId));
    await this.assertAcceptedDriver(userId, rideId);
    return this.suggestionsFor(ride);
  }

  /**
   * Accord dans une conversation (proposition de trajet ou demande publiée dans un groupe) : le
   * conducteur et le passager ont tous deux dit oui, le passager est donc accepté directement.
   * Mêmes contrôles qu'une place demandée (trajet ouvert, place libre, solde, pas déjà engagé ce
   * jour-là), sans limite de détour : le conducteur a choisi de prendre cette personne.
   */
  async joinByAgreement(rideId: string, passengerId: string): Promise<void> {
    const peek = this.assertOpen(await this.repo.peekRide(rideId));
    const detourS = await this.agreedDetour(rideId, passengerId);
    await this.requireFunds(passengerId, rideId, detourS);
    const result = await this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      if (ride.driverId === passengerId) throw new AppError(409, 'own_ride', "C'est ta propre voiture");
      const parts = await this.repo.participants([rideId], tx);
      if (parts.find((p) => p.role === 'driver')?.status !== 'accepted') {
        throw new AppError(409, 'ride_unavailable', 'Cette voiture ne peut plus te prendre');
      }
      const me = parts.find((p) => p.userId === passengerId);
      if (me?.status === 'accepted') return null; // déjà à bord : rien à refaire
      const taken = parts.filter((p) => p.role === 'passenger' && ACTIVE(p) && p.userId !== passengerId).length;
      if (taken >= ride.seatsTotal) throw new AppError(409, 'ride_full', 'Cette voiture est complète');
      for (const other of await this.repo.otherActiveRides(passengerId, ride.day, ride.direction, rideId, tx)) {
        const theirs = (await this.repo.participants([other.ride_id], tx)).find((p) => p.userId === passengerId)!;
        if (theirs.role === 'driver') throw new AppError(409, 'already_driving', 'Tu conduis déjà ce jour-là');
        if (theirs.status === 'accepted') throw new AppError(409, 'already_committed', 'Tu as déjà un trajet ce jour-là');
        await this.repo.setParticipantStatus(other.ride_id, passengerId, 'declined', tx);
      }
      await this.repo.addPassenger(rideId, passengerId, detourS, tx, 'accepted');
      if (ride.status === 'proposed') await this.repo.setRideStatus(rideId, 'confirmed', tx);
      await this.repo.invalidatePlan(rideId, tx);
      return { driverId: ride.driverId };
    });
    if (!result) return;
    await this.onRideChanged(rideId).catch(() => undefined);
    await this.notifier.notify([result.driverId, passengerId], { type: 'carpool_joined', rideId }).catch(() => undefined);
  }

  /** Détour ajouté par ce passager au trajet (estimé, comme pour les suggestions). */
  private async agreedDetour(rideId: string, passengerId: string): Promise<number> {
    const ride = this.assertOpen(await this.repo.findRide(rideId));
    const passengers = (await this.repo.participants([rideId])).filter(
      (p) => p.role === 'passenger' && ACTIVE(p) && p.userId !== passengerId,
    );
    const homes = await this.repo.homesAndVehicles([ride.driverId, passengerId, ...passengers.map((p) => p.userId)]);
    const driver = homes.get(ride.driverId);
    const mine = homes.get(passengerId);
    if (!mine) throw new AppError(409, 'profile_incomplete', 'Ajoute ton adresse pour trouver un trajet');
    if (!driver) throw new AppError(409, 'ride_unavailable', 'Cette voiture ne peut plus te prendre');
    const params = await this.params(await this.repo.campusLocation(ride.campusId));
    const others = passengers.map((p) => homes.get(p.userId)).filter((h): h is NonNullable<typeof h> => Boolean(h));
    const home = { lat: driver.lat, lon: driver.lon };
    return Math.round(detourSeconds(home, [...others, mine], params) - detourSeconds(home, others, params));
  }

  /** Le conducteur propose une place : le passager reçoit une proposition à accepter. */
  async invite(userId: string, rideId: string, passengerId: string): Promise<ProposalView> {
    const peek = this.assertOpen(await this.repo.peekRide(rideId));
    return this.repo.transaction(async (tx) => {
      await this.repo.lockDay(tx, peek.day);
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      await this.assertAcceptedDriver(userId, rideId, tx);
      const view = await this.suggestionsFor(ride, tx);
      if (view.seatsLeft <= 0) throw new AppError(409, 'ride_full', 'Ta voiture est complète');
      const pick = view.suggestions.find((s) => s.person.userId === passengerId);
      if (!pick) throw new AppError(409, 'suggestion_unavailable', 'Cette personne ne peut plus être proposée');
      await this.repo.addPassenger(rideId, passengerId, pick.person.detourMinutes * 60, tx, 'proposed');
      return this.viewFor(userId, rideId, tx);
    });
  }

  private async assertAcceptedDriver(userId: string, rideId: string, db?: DbOrTx): Promise<void> {
    const me = (await this.repo.participants([rideId], db)).find((p) => p.userId === userId);
    if (!me || me.role !== 'driver') throw new AppError(403, 'forbidden', 'Réservé au conducteur de ce trajet');
    if (me.status !== 'accepted') throw new AppError(409, 'accept_first', "Accepte d'abord ce trajet");
  }

  private async suggestionsFor(ride: RideRow, db?: DbOrTx): Promise<SuggestionsView> {
    const parts = await this.repo.participants([ride.id], db);
    const passengers = parts.filter((p) => p.role === 'passenger' && ACTIVE(p));
    const seatsLeft = ride.seatsTotal - passengers.length;
    const busy = await this.repo.busyUsers(ride.day, ride.direction, db);
    const declines = await this.repo.declines(ride.day, ride.direction, db);
    const needs = (await this.repo.needsForDay(ride.day, db)).filter(
      (n) =>
        n.campusId === ride.campusId &&
        n.roleMode !== 'always_driver' &&
        !busy.has(n.userId) &&
        !declines.has(`${ride.driverId}|${n.userId}`),
    );
    const pauses = await this.repo.pausesFor(
      needs.map((n) => n.userId),
      db,
    );
    const params = await this.params(await this.repo.campusLocation(ride.campusId, db));
    const candidates = needs.filter(
      (n) =>
        !isPausedOn(pauses.get(n.userId) ?? [], ride.day) &&
        isTimeCompatible(ride.targetTime, ride.direction === 'to_campus' ? n.start : n.end, params),
    );

    const homes = await this.repo.homesAndVehicles([ride.driverId, ...passengers.map((p) => p.userId)], db);
    const driverInfo = homes.get(ride.driverId);
    const consumption = await this.repo.vehicleConsumption(ride.driverId, db);
    if (!driverInfo?.maxDetourMinutes || consumption === null) return { seatsLeft, current: null, suggestions: [] };
    const driverHome = { lat: driverInfo.lat, lon: driverInfo.lon };
    const current = passengers.map((p) => homes.get(p.userId)).filter((h): h is NonNullable<typeof h> => Boolean(h));

    const fuel = await this.settings.get('pricing.fuelPriceCentsPerLitre');
    const commission = await this.settings.get('pricing.commissionCentsPerPassenger');
    const priceFor = (stops: { lat: number; lon: number }[]) => {
      const ordered = pickupOrder(driverHome, stops.map((home) => ({ home }))).map((s) => s.home);
      const { distanceM } = estimateRoute([driverHome, ...ordered, params.campus], params);
      return estimatePrice({
        consumptionLPer100km: consumption,
        distanceM,
        fuelPriceCentsPerLitre: fuel,
        commissionCentsPerPassenger: commission,
        persons: stops.length + 1,
      });
    };
    const now = priceFor(current);
    const before = detourSeconds(driverHome, current, params);
    const users = await this.repo.publicUsers(
      candidates.map((c) => c.userId),
      db,
    );

    const suggestions = candidates
      .map((c) => {
        const home = { lat: c.lat, lon: c.lon };
        const after = detourSeconds(driverHome, [...current, home], params);
        const price = priceFor([...current, home]);
        const info = users.get(c.userId)!;
        return {
          extra: after - before,
          reliability: c.reliability,
          suggestion: {
            person: publicPerson({ ...info, rideId: ride.id, role: 'passenger', status: 'suggested', detourS: null }, after - before),
            withinDetourLimit: after <= driverInfo.maxDetourMinutes! * 60,
            shareCents: price.shareCents,
            passengerPaysCents: price.passengerPaysCents,
          },
        };
      })
      .sort(
        (a, b) =>
          rankingCost(a.extra, [a.reliability], params.reliabilityWeightSeconds) -
            rankingCost(b.extra, [b.reliability], params.reliabilityWeightSeconds) ||
          a.suggestion.person.userId.localeCompare(b.suggestion.person.userId),
      )
      .slice(0, MAX_SUGGESTIONS)
      .map((s) => s.suggestion);

    return {
      seatsLeft,
      current: { persons: now.persons, shareCents: now.shareCents, passengerPaysCents: now.passengerPaysCents },
      suggestions,
    };
  }

  /** Voitures où l'utilisateur peut monter : place libre, horaire et détour compatibles. */
  private async joinable(
    userId: string,
    day: string,
    direction: Direction,
    excludeRideId: string | null,
    db?: DbOrTx,
    explicitTime?: string,
    fallbackTime?: Date,
  ): Promise<JoinableRide[]> {
    const me = (await this.repo.needsForDay(day, db)).find((n) => n.userId === userId);
    const homes = await this.repo.homesAndVehicles([userId], db);
    const myHome = homes.get(userId);
    if (!myHome) throw new AppError(409, 'profile_incomplete', 'Ajoute ton adresse pour trouver un trajet');
    const myTime = explicitTime
      ? parisToUtc(day, explicitTime)
      : me
        ? direction === 'to_campus'
          ? me.start
          : me.end
        : (fallbackTime ?? null);
    if (!myTime) throw new AppError(400, 'time_required', 'Indique une heure pour ce jour');

    const declines = await this.repo.declines(day, direction, db);
    const rides = (await this.repo.openRides(day, direction, db)).filter(
      (r) => r.id !== excludeRideId && r.driverId !== userId && !declines.has(`${r.driverId}|${userId}`),
    );
    if (rides.length === 0) return [];

    const parts = await this.repo.participants(rides.map((r) => r.id), db);
    const people = await this.repo.homesAndVehicles([...new Set(parts.map((p) => p.userId))], db);
    const results: (JoinableRide & { cost: number })[] = [];

    for (const ride of rides) {
      const rideParts = parts.filter((p) => p.rideId === ride.id);
      if (rideParts.some((p) => p.userId === userId && ACTIVE(p))) continue;
      const driver = rideParts.find((p) => p.role === 'driver')!;
      const driverInfo = people.get(driver.userId);
      if (!driverInfo?.maxDetourMinutes) continue;
      const params = await this.params(await this.repo.campusLocation(ride.campusId, db));
      if (!isTimeCompatible(ride.targetTime, myTime, params)) continue;
      const others = rideParts
        .filter((p) => p.role === 'passenger' && ACTIVE(p) && p.userId !== userId)
        .map((p) => people.get(p.userId))
        .filter((h): h is NonNullable<typeof h> => Boolean(h));
      const driverHome = { lat: driverInfo.lat, lon: driverInfo.lon };
      const before = detourSeconds(driverHome, others, params);
      const after = detourSeconds(driverHome, [...others, myHome], params);
      if (after > driverInfo.maxDetourMinutes * 60) continue;
      results.push({
        rideId: ride.id,
        day: ride.day,
        direction: ride.direction,
        time: ride.targetTime,
        seatsLeft: ride.seatsTotal - others.length,
        driver: publicPerson(driver, after - before),
        cost: rankingCost(after - before, [driver.reliability], params.reliabilityWeightSeconds),
      });
    }
    return results.sort((a, b) => a.cost - b.cost || a.rideId.localeCompare(b.rideId)).map(({ cost: _cost, ...rest }) => rest);
  }
}
