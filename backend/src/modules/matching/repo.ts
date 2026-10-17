import { and, eq, inArray, ne, sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import {
  matchingRuns,
  proposalDeclines,
  rideParticipants,
  rides,
  searchQuota,
} from '../../db/schema.js';
import type { Pause } from '../profile/domain.js';
import type { Direction, PlannedRide, RoleMode } from './domain.js';

type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;

export interface NeedRow {
  userId: string;
  campusId: string;
  lat: number;
  lon: number;
  start: Date;
  end: Date;
  roleMode: RoleMode;
  seats: number | null;
  maxDetourMinutes: number | null;
  reliability: number;
}

export interface ParticipantRow {
  rideId: string;
  userId: string;
  role: 'driver' | 'passenger';
  status: string;
  detourS: number | null;
  firstName: string;
  photoUrl: string | null;
  sector: string | null;
  reliability: number;
  /** Lu seulement par `participants` (annulation pendant le trajet). */
  presenceValidated?: boolean;
}

export interface RideRow {
  id: string;
  driverId: string;
  direction: Direction;
  campusId: string;
  day: string;
  targetTime: Date;
  seatsTotal: number;
  status: string;
}

export class MatchingRepo {
  constructor(private readonly db: Db) {}

  transaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.transaction(fn);
  }

  /** Verrou par jour : deux générations du même jour ne se chevauchent pas. */
  async lockDay(tx: Tx, day: string): Promise<void> {
    await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${`matching:${day}`}))`);
  }

  /**
   * Besoins du jour : utilisateurs actifs avec un créneau effectif (agenda connecté, sinon
   * semaine type), une adresse et un campus. Les pauses sont filtrées par le service.
   */
  async needsForDay(day: string, db: DbOrTx = this.db): Promise<NeedRow[]> {
    const { rows } = await db.execute<{
      user_id: string;
      campus_id: string;
      lat: number;
      lon: number;
      start_at: Date;
      end_at: Date;
      role_mode: RoleMode;
      seats: number | null;
      max_detour: number | null;
      reliability: string;
    }>(sql`
      SELECT u.id AS user_id, u.campus_id,
             ST_Y(u.home_location::geometry) AS lat, ST_X(u.home_location::geometry) AS lon,
             s.start_at, s.end_at, u.role_mode, v.default_seats AS seats,
             v.max_detour_minutes AS max_detour, u.reliability_score AS reliability
      FROM schedule_slots s
      JOIN users u ON u.id = s.user_id
      LEFT JOIN vehicles v ON v.user_id = u.id
      WHERE s.day = ${day}
        AND u.deleted_at IS NULL AND u.home_location IS NOT NULL AND u.campus_id IS NOT NULL
        AND s.source = CASE WHEN EXISTS (SELECT 1 FROM calendar_connections c WHERE c.user_id = u.id)
                            THEN 'calendar' ELSE 'manual' END`);
    return rows.map((r) => ({
      userId: r.user_id,
      campusId: r.campus_id,
      lat: Number(r.lat),
      lon: Number(r.lon),
      start: new Date(r.start_at),
      end: new Date(r.end_at),
      roleMode: r.role_mode,
      seats: r.seats,
      maxDetourMinutes: r.max_detour,
      reliability: Number(r.reliability),
    }));
  }

  async pausesFor(userIds: readonly string[], db: DbOrTx = this.db): Promise<Map<string, Pause[]>> {
    const map = new Map<string, Pause[]>();
    if (userIds.length === 0) return map;
    const { rows } = await db.execute<{ user_id: string; starts_on: string; ends_on: string; recurrence: Pause['recurrence'] }>(
      sql`SELECT user_id, starts_on::text, ends_on::text, recurrence FROM pauses
          WHERE user_id IN (${sql.join(userIds.map((id) => sql`${id}::uuid`), sql`, `)})`,
    );
    for (const r of rows) {
      map.set(r.user_id, [...(map.get(r.user_id) ?? []), { startsOn: r.starts_on, endsOn: r.ends_on, recurrence: r.recurrence }]);
    }
    return map;
  }

  async campusLocation(campusId: string, db: DbOrTx = this.db): Promise<{ lat: number; lon: number }> {
    const { rows } = await db.execute<{ lat: number; lon: number }>(
      sql`SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lon FROM campuses WHERE id = ${campusId}`,
    );
    return { lat: Number(rows[0]!.lat), lon: Number(rows[0]!.lon) };
  }

  /**
   * Utilisateurs déjà engagés ce jour-là dans ce sens : trajet confirmé ou dont un
   * participant a accepté. Ces trajets ne sont pas recalculés.
   */
  async lockedUsers(day: string, direction: Direction, db: DbOrTx = this.db): Promise<Set<string>> {
    const { rows } = await db.execute<{ user_id: string }>(sql`
      SELECT p.user_id FROM ride_participants p
      JOIN rides r ON r.id = p.ride_id
      WHERE r.day = ${day} AND r.direction = ${direction} AND r.status <> 'cancelled'
        AND p.status NOT IN ('declined', 'cancelled')
        AND (r.status = 'confirmed' OR EXISTS (
          SELECT 1 FROM ride_participants a WHERE a.ride_id = r.id AND a.status IN ('accepted', 'requested')))`);
    return new Set(rows.map((r) => r.user_id));
  }

  /** Supprime les propositions encore ouvertes (personne n'a accepté ni demandé) du jour et du sens. */
  async deleteOpenRides(day: string, direction: Direction, db: DbOrTx = this.db): Promise<void> {
    await db.execute(sql`
      DELETE FROM rides r
      WHERE r.day = ${day} AND r.direction = ${direction} AND r.status = 'proposed'
        AND NOT EXISTS (SELECT 1 FROM ride_participants a WHERE a.ride_id = r.id AND a.status IN ('accepted', 'requested'))`);
  }

  async declines(day: string, direction: Direction, db: DbOrTx = this.db): Promise<Set<string>> {
    const rows = await db
      .select({ userId: proposalDeclines.userId, otherUserId: proposalDeclines.otherUserId })
      .from(proposalDeclines)
      .where(and(eq(proposalDeclines.day, day), eq(proposalDeclines.direction, direction)));
    // Un refus vaut dans les deux sens : ni l'un ni l'autre ne revoit cette paire.
    return new Set(rows.flatMap((r) => [`${r.userId}|${r.otherUserId}`, `${r.otherUserId}|${r.userId}`]));
  }

  async recordDecline(userId: string, otherUserId: string, day: string, direction: Direction, db: DbOrTx = this.db) {
    await db.insert(proposalDeclines).values({ userId, otherUserId, day, direction }).onConflictDoNothing();
  }

  async insertRide(
    planned: PlannedRide,
    meta: { day: string; direction: Direction; campusId: string },
    db: DbOrTx = this.db,
  ): Promise<string> {
    const [ride] = await db
      .insert(rides)
      .values({
        driverId: planned.driverId,
        direction: meta.direction,
        campusId: meta.campusId,
        day: meta.day,
        targetTime: planned.targetTime,
        seatsTotal: planned.seats,
      })
      .returning({ id: rides.id });
    await db.insert(rideParticipants).values([
      { rideId: ride!.id, userId: planned.driverId, role: 'driver', detourS: Math.round(planned.totalDetourSeconds) },
      ...planned.passengers.map((p) => ({
        rideId: ride!.id,
        userId: p.userId,
        role: 'passenger' as const,
        detourS: Math.round(p.detourSeconds),
      })),
    ]);
    return ride!.id;
  }

  /** Lecture sans verrou : sert à connaître le jour avant de prendre le verrou du jour. */
  async peekRide(rideId: string): Promise<RideRow | undefined> {
    const [ride] = await this.db.select().from(rides).where(eq(rides.id, rideId));
    return ride ? { ...ride, day: ride.day!, direction: ride.direction } : undefined;
  }

  async findRide(rideId: string, db: DbOrTx = this.db): Promise<RideRow | undefined> {
    const [ride] = await db
      .select()
      .from(rides)
      .where(eq(rides.id, rideId))
      .for('update');
    return ride ? { ...ride, day: ride.day!, direction: ride.direction } : undefined;
  }

  async participants(rideIds: readonly string[], db: DbOrTx = this.db): Promise<ParticipantRow[]> {
    if (rideIds.length === 0) return [];
    const { rows } = await db.execute<{
      ride_id: string;
      user_id: string;
      role: 'driver' | 'passenger';
      status: string;
      detour_s: number | null;
      first_name: string;
      photo_url: string | null;
      home_sector: string | null;
      reliability: string;
      presence_validated: boolean;
    }>(sql`
      SELECT p.ride_id, p.user_id, p.role, p.status, p.detour_s, p.presence_validated_at IS NOT NULL AS presence_validated,
             u.first_name, u.photo_url, u.home_sector, u.reliability_score AS reliability
      FROM ride_participants p JOIN users u ON u.id = p.user_id
      WHERE p.ride_id IN (${sql.join(rideIds.map((id) => sql`${id}::uuid`), sql`, `)})`);
    return rows.map((r) => ({
      rideId: r.ride_id,
      userId: r.user_id,
      role: r.role,
      status: r.status,
      detourS: r.detour_s,
      firstName: r.first_name,
      photoUrl: r.photo_url,
      sector: r.home_sector,
      reliability: Number(r.reliability),
      presenceValidated: r.presence_validated,
    }));
  }

  /** Trajets d'un utilisateur sur une période (hors ceux qu'il a refusés). */
  async ridesForUser(userId: string, fromDay: string, toDayExclusive: string, db: DbOrTx = this.db): Promise<RideRow[]> {
    const { rows } = await db.execute<{
      id: string;
      driver_id: string;
      direction: Direction;
      campus_id: string;
      day: string;
      target_time: Date;
      seats_total: number;
      status: string;
    }>(sql`
      SELECT r.id, r.driver_id, r.direction, r.campus_id, r.day::text, r.target_time, r.seats_total, r.status
      FROM rides r JOIN ride_participants p ON p.ride_id = r.id
      WHERE p.user_id = ${userId} AND p.status NOT IN ('declined')
        AND r.day >= ${fromDay} AND r.day < ${toDayExclusive}
      ORDER BY r.day, r.direction DESC, r.target_time`);
    return rows.map(toRide);
  }

  /** Trajets du jour et du sens où une place peut encore être prise. */
  async openRides(day: string, direction: Direction, db: DbOrTx = this.db): Promise<RideRow[]> {
    const { rows } = await db.execute<{
      id: string;
      driver_id: string;
      direction: Direction;
      campus_id: string;
      day: string;
      target_time: Date;
      seats_total: number;
      status: string;
    }>(sql`
      SELECT r.id, r.driver_id, r.direction, r.campus_id, r.day::text, r.target_time, r.seats_total, r.status
      FROM rides r
      WHERE r.day = ${day} AND r.direction = ${direction} AND r.status IN ('proposed', 'confirmed')
        AND (SELECT count(*) FROM ride_participants p
             WHERE p.ride_id = r.id AND p.role = 'passenger' AND p.status NOT IN ('declined', 'cancelled')) < r.seats_total`);
    return rows.map(toRide);
  }

  async homesAndVehicles(userIds: readonly string[], db: DbOrTx = this.db) {
    if (userIds.length === 0) return new Map<string, { lat: number; lon: number; maxDetourMinutes: number | null }>();
    const { rows } = await db.execute<{ id: string; lat: number; lon: number; max_detour: number | null }>(sql`
      SELECT u.id, ST_Y(u.home_location::geometry) AS lat, ST_X(u.home_location::geometry) AS lon,
             v.max_detour_minutes AS max_detour
      FROM users u LEFT JOIN vehicles v ON v.user_id = u.id
      WHERE u.home_location IS NOT NULL
        AND u.id IN (${sql.join(userIds.map((id) => sql`${id}::uuid`), sql`, `)})`);
    return new Map(rows.map((r) => [r.id, { lat: Number(r.lat), lon: Number(r.lon), maxDetourMinutes: r.max_detour }]));
  }

  async setParticipantStatus(rideId: string, userId: string, status: 'accepted' | 'declined' | 'requested', db: DbOrTx = this.db) {
    await db
      .update(rideParticipants)
      .set({ status })
      .where(and(eq(rideParticipants.rideId, rideId), eq(rideParticipants.userId, userId)));
  }

  async addPassenger(
    rideId: string,
    userId: string,
    detourS: number,
    db: DbOrTx = this.db,
    status: 'accepted' | 'proposed' | 'requested' = 'accepted',
  ) {
    await db
      .insert(rideParticipants)
      .values({ rideId, userId, role: 'passenger', status, detourS })
      .onConflictDoUpdate({
        target: [rideParticipants.rideId, rideParticipants.userId],
        set: { status, detourS },
      });
  }

  /** Utilisateurs déjà dans un trajet actif ce jour-là dans ce sens (conducteur ou passager). */
  async busyUsers(day: string, direction: Direction, db: DbOrTx = this.db): Promise<Set<string>> {
    const { rows } = await db.execute<{ user_id: string }>(sql`
      SELECT p.user_id FROM ride_participants p JOIN rides r ON r.id = p.ride_id
      WHERE r.day = ${day} AND r.direction = ${direction} AND r.status <> 'cancelled'
        AND p.status NOT IN ('declined', 'cancelled')`);
    return new Set(rows.map((r) => r.user_id));
  }

  /** Informations publiques (avant acceptation) d'utilisateurs hors trajet. */
  async publicUsers(userIds: readonly string[], db: DbOrTx = this.db): Promise<Map<string, Omit<ParticipantRow, 'rideId' | 'role' | 'status' | 'detourS'>>> {
    if (userIds.length === 0) return new Map();
    const { rows } = await db.execute<{
      id: string;
      first_name: string;
      photo_url: string | null;
      home_sector: string | null;
      reliability: string;
    }>(sql`
      SELECT id, first_name, photo_url, home_sector, reliability_score AS reliability FROM users
      WHERE id IN (${sql.join(userIds.map((id) => sql`${id}::uuid`), sql`, `)})`);
    return new Map(
      rows.map((r) => [
        r.id,
        { userId: r.id, firstName: r.first_name, photoUrl: r.photo_url, sector: r.home_sector, reliability: Number(r.reliability) },
      ]),
    );
  }

  async vehicleConsumption(userId: string, db: DbOrTx = this.db): Promise<number | null> {
    const { rows } = await db.execute<{ consumption: string }>(
      sql`SELECT consumption_l_per_100km AS consumption FROM vehicles WHERE user_id = ${userId}`,
    );
    return rows[0] ? Number(rows[0].consumption) : null;
  }

  /** Les arrêts d'un trajet ont changé : son plan (tracé, heures) est à recalculer. */
  async invalidatePlan(rideId: string, db: DbOrTx = this.db) {
    await db.update(rides).set({ plannedAt: null }).where(eq(rides.id, rideId));
  }

  async setRideStatus(rideId: string, status: 'proposed' | 'confirmed' | 'cancelled', db: DbOrTx = this.db) {
    await db.update(rides).set({ status }).where(eq(rides.id, rideId));
  }

  async cancelParticipant(rideId: string, userId: string, now: Date, db: DbOrTx = this.db) {
    await db
      .update(rideParticipants)
      .set({ status: 'cancelled', cancelledAt: now })
      .where(and(eq(rideParticipants.rideId, rideId), eq(rideParticipants.userId, userId)));
  }

  async cancelParticipants(rideId: string, now: Date, db: DbOrTx = this.db) {
    await db
      .update(rideParticipants)
      .set({ status: 'cancelled', cancelledAt: now })
      .where(and(eq(rideParticipants.rideId, rideId), ne(rideParticipants.status, 'declined')));
  }

  /**
   * Retire un utilisateur des propositions non confirmées d'un jour (horaire modifié). Un trajet
   * qu'il conduit et qu'un passager a déjà accepté n'est pas effacé en silence : il est annulé et
   * ses passagers acceptés sont renvoyés pour être prévenus.
   */
  async releaseUnconfirmed(userId: string, day: string, now: Date, db: DbOrTx = this.db): Promise<{ rideId: string; passengers: string[] }[]> {
    const { rows } = await db.execute<{ ride_id: string; passengers: string[] }>(sql`
      SELECT r.id AS ride_id, array_agg(p.user_id) AS passengers
      FROM rides r JOIN ride_participants p ON p.ride_id = r.id
      WHERE r.day = ${day} AND r.driver_id = ${userId} AND r.status = 'proposed'
        AND p.role = 'passenger' AND p.status IN ('accepted', 'requested')
      GROUP BY r.id`);
    for (const r of rows) {
      await this.setRideStatus(r.ride_id, 'cancelled', db);
      await this.cancelParticipants(r.ride_id, now, db);
    }
    await db.execute(sql`
      DELETE FROM rides r WHERE r.day = ${day} AND r.driver_id = ${userId} AND r.status = 'proposed'`);
    await db.execute(sql`
      DELETE FROM ride_participants p USING rides r
      WHERE p.ride_id = r.id AND r.day = ${day} AND p.user_id = ${userId}
        AND p.role = 'passenger' AND r.status = 'proposed'`);
    return rows.map((r) => ({ rideId: r.ride_id, passengers: r.passengers }));
  }

  async otherActiveRides(userId: string, day: string, direction: Direction, exceptRideId: string, db: DbOrTx = this.db) {
    const { rows } = await db.execute<{ ride_id: string; driver_id: string }>(sql`
      SELECT p.ride_id, r.driver_id FROM ride_participants p JOIN rides r ON r.id = p.ride_id
      WHERE p.user_id = ${userId} AND r.day = ${day} AND r.direction = ${direction}
        AND r.id <> ${exceptRideId} AND r.status <> 'cancelled'
        AND p.status NOT IN ('declined', 'cancelled')`);
    return rows;
  }

  async isWeekGenerated(week: string, db: DbOrTx = this.db): Promise<boolean> {
    const rows = await db.select().from(matchingRuns).where(eq(matchingRuns.week, week));
    return rows.length > 0;
  }

  async markWeekGenerated(week: string, now: Date, db: DbOrTx = this.db): Promise<void> {
    await db.insert(matchingRuns).values({ week, generatedAt: now }).onConflictDoNothing();
  }

  /** Incrémente le compteur de recherches du jour et renvoie la nouvelle valeur. */
  async incrementSearch(userId: string, day: string): Promise<number> {
    const [row] = await this.db
      .insert(searchQuota)
      .values({ userId, day, count: 1 })
      .onConflictDoUpdate({ target: [searchQuota.userId, searchQuota.day], set: { count: sql`${searchQuota.count} + 1` } })
      .returning({ count: searchQuota.count });
    return row!.count;
  }

  async userIdsInRides(rideIds: readonly string[], db: DbOrTx = this.db): Promise<string[]> {
    if (rideIds.length === 0) return [];
    const rows = await db
      .select({ userId: rideParticipants.userId })
      .from(rideParticipants)
      .where(inArray(rideParticipants.rideId, [...rideIds]));
    return rows.map((r) => r.userId);
  }
}

function toRide(r: {
  id: string;
  driver_id: string;
  direction: Direction;
  campus_id: string;
  day: string;
  target_time: Date;
  seats_total: number;
  status: string;
}): RideRow {
  return {
    id: r.id,
    driverId: r.driver_id,
    direction: r.direction,
    campusId: r.campus_id,
    day: r.day,
    targetTime: new Date(r.target_time),
    seatsTotal: r.seats_total,
    status: r.status,
  };
}
