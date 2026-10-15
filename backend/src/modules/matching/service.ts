import { AppError } from '../../shared/errors.js';
import { sectorCenter } from '../../shared/geo.js';
import { addDaysIso, isoWeekOf, parisDateOf, parisToUtc, weekDays } from '../../shared/time.js';
import { isPausedOn } from '../profile/domain.js';
import type { SettingsService } from '../settings/service.js';
import {
  detourSeconds,
  type Direction,
  isTimeCompatible,
  type MatchParams,
  matchSlot,
  type Need,
} from './domain.js';
import type { DbOrTx, MatchingRepo, ParticipantRow, RideRow } from './repo.js';

const DIRECTIONS: Direction[] = ['to_campus', 'from_campus'];
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

export class MatchingService {
  constructor(
    private readonly repo: MatchingRepo,
    private readonly settings: SettingsService,
    private readonly clock: () => Date,
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
      await this.repo.transaction(async (tx) => {
        await this.repo.lockDay(tx, day);
        await this.repo.releaseUnconfirmed(userId, day, tx);
      });
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
    await this.ensureWeek(week);
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
    return ride;
  }

  /**
   * Accepter : sa propre proposition, ou une autre voiture trouvée par « voir d'autres » ou
   * la recherche (le serveur revérifie places, horaire et détour). Le trajet est confirmé
   * quand le conducteur et au moins un passager ont accepté (confirmation à deux).
   */
  async accept(userId: string, rideId: string): Promise<ProposalView> {
    return this.repo.transaction(async (tx) => {
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      await this.repo.lockDay(tx, ride.day);
      const parts = await this.repo.participants([rideId], tx);
      const me = parts.find((p) => p.userId === userId);

      if (me) {
        if (!ACTIVE(me)) throw new AppError(409, 'proposal_declined', 'Tu as refusé cette proposition');
        await this.repo.setParticipantStatus(rideId, userId, 'accepted', tx);
      } else {
        const joinable = await this.joinable(userId, ride.day, ride.direction, null, tx);
        const match = joinable.find((j) => j.rideId === rideId);
        if (!match) throw new AppError(409, 'ride_unavailable', 'Cette voiture ne peut plus te prendre');
        for (const other of await this.repo.otherActiveRides(userId, ride.day, ride.direction, rideId, tx)) {
          const otherParts = await this.repo.participants([other.ride_id], tx);
          const mine = otherParts.find((p) => p.userId === userId)!;
          if (mine.role === 'driver') throw new AppError(409, 'already_driving', 'Tu conduis déjà ce jour-là');
          if (mine.status === 'accepted') throw new AppError(409, 'already_committed', 'Tu as déjà un trajet ce jour-là');
          await this.repo.setParticipantStatus(other.ride_id, userId, 'declined', tx);
        }
        await this.repo.addPassenger(rideId, userId, match.driver.detourMinutes * 60, tx);
      }

      const updated = await this.repo.participants([rideId], tx);
      const driverAccepted = updated.some((p) => p.role === 'driver' && p.status === 'accepted');
      const passengerAccepted = updated.some((p) => p.role === 'passenger' && p.status === 'accepted');
      if (driverAccepted && passengerAccepted && ride.status === 'proposed') {
        await this.repo.setRideStatus(rideId, 'confirmed', tx);
      }
      return this.viewFor(userId, rideId, tx);
    });
  }

  /**
   * Refuser une proposition encore ouverte. Passager : la paire n'est plus reproposée ce
   * jour-là. Conducteur : le trajet est annulé et ses passagers sont relancés.
   * Après acceptation, c'est une annulation (jalon M5).
   */
  async decline(userId: string, rideId: string): Promise<void> {
    const ride = await this.repo.transaction(async (tx) => {
      const ride = this.assertOpen(await this.repo.findRide(rideId, tx));
      await this.repo.lockDay(tx, ride.day);
      const parts = await this.repo.participants([rideId], tx);
      const me = parts.find((p) => p.userId === userId);
      if (!me) throw new AppError(404, 'not_found', 'Ressource introuvable');
      if (me.status !== 'proposed') {
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

  /** Voitures où l'utilisateur peut monter : place libre, horaire et détour compatibles. */
  private async joinable(
    userId: string,
    day: string,
    direction: Direction,
    excludeRideId: string | null,
    db?: DbOrTx,
    explicitTime?: string,
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
        : null;
    if (!myTime) throw new AppError(400, 'time_required', 'Indique une heure pour ce jour');

    const declines = await this.repo.declines(day, direction, db);
    const rides = (await this.repo.openRides(day, direction, db)).filter(
      (r) => r.id !== excludeRideId && r.driverId !== userId && !declines.has(`${r.driverId}|${userId}`),
    );
    if (rides.length === 0) return [];

    const parts = await this.repo.participants(rides.map((r) => r.id), db);
    const people = await this.repo.homesAndVehicles([...new Set(parts.map((p) => p.userId))], db);
    const results: (JoinableRide & { extra: number; reliability: number })[] = [];

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
        extra: after - before,
        reliability: driver.reliability,
      });
    }
    return results
      .sort((a, b) => a.extra - b.extra || b.reliability - a.reliability || a.rideId.localeCompare(b.rideId))
      .map(({ extra: _extra, reliability: _reliability, ...rest }) => rest);
  }
}
