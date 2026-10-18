import { and, eq, sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import { rideParticipants, rides } from '../../db/schema.js';
import type { LatLon } from '../../shared/geo.js';
import type { Direction } from './domain.js';

export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;

export interface RideInfo {
  id: string;
  driverId: string;
  direction: Direction;
  day: string;
  targetTime: Date;
  status: string;
  seatsTotal: number;
  distanceM: number | null;
  durationS: number | null;
  routeEstimated: boolean;
  plannedAt: Date | null;
  startedAt: Date | null;
  campus: LatLon & { name: string };
  /** Consommation du véhicule du conducteur (null s'il l'a retiré). */
  consumptionLPer100km: number | null;
  /** Modèle et couleur de la voiture du conducteur, s'il les a donnés. */
  vehicle: { model: string | null; color: string | null } | null;
}

export interface Member {
  userId: string;
  role: 'driver' | 'passenger';
  status: string;
  firstName: string;
  lastName: string;
  photoUrl: string | null;
  home: LatLon | null;
  homeLabel: string | null;
  useMeetingPoint: boolean;
  meetingPoint: LatLon | null;
  meetingLabel: string | null;
  stopOrder: number | null;
  eta: Date | null;
  presenceValidatedAt: Date | null;
  /** Arrivé à destination (passager) : son trajet est payé à la clôture. */
  arrivedAt: Date | null;
  /** Trajet terminé de son côté (arrivé, ou sorti avant l'arrivée). */
  endedAt: Date | null;
  detourS: number | null;
  /** Distance à bord, depuis le campus (calculée avec le plan) ; null avant le plan. */
  onboardM: number | null;
}

export const isAccepted = (m: Member) => m.status === 'accepted' || m.status === 'picked_up';

/** Point de prise en charge : point de rendez-vous s'il est choisi, sinon le domicile. */
export function pickupOf(m: Member): { point: LatLon; label: string; isMeetingPoint: boolean } | null {
  if (m.useMeetingPoint && m.meetingPoint) {
    return { point: m.meetingPoint, label: m.meetingLabel ?? '', isMeetingPoint: true };
  }
  return m.home ? { point: m.home, label: m.homeLabel ?? '', isMeetingPoint: false } : null;
}

export class RidesRepo {
  constructor(private readonly db: Db) {}

  transaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.transaction(fn);
  }

  async ride(rideId: string, db: DbOrTx = this.db, forUpdate = false): Promise<RideInfo | undefined> {
    const { rows } = await db.execute<{
      id: string;
      driver_id: string;
      direction: Direction;
      day: string;
      target_time: Date;
      status: string;
      seats_total: number;
      distance_m: number | null;
      duration_s: number | null;
      route_estimated: boolean;
      planned_at: Date | null;
      started_at: Date | null;
      campus_name: string;
      campus_lat: number;
      campus_lon: number;
      consumption: string | null;
      vehicle_model: string | null;
      vehicle_color: string | null;
    }>(sql`
      SELECT r.id, r.driver_id, r.direction, r.day::text, r.target_time, r.status, r.seats_total,
             r.distance_m, r.duration_s, r.route_estimated, r.planned_at, r.started_at,
             c.name AS campus_name, ST_Y(c.location::geometry) AS campus_lat,
             ST_X(c.location::geometry) AS campus_lon, v.consumption_l_per_100km AS consumption,
             v.model AS vehicle_model, v.color AS vehicle_color
      FROM rides r JOIN campuses c ON c.id = r.campus_id
      LEFT JOIN vehicles v ON v.user_id = r.driver_id
      WHERE r.id = ${rideId}
      ${forUpdate ? sql`FOR UPDATE OF r` : sql``}`);
    const r = rows[0];
    if (!r) return undefined;
    return {
      id: r.id,
      driverId: r.driver_id,
      direction: r.direction,
      day: r.day,
      targetTime: new Date(r.target_time),
      status: r.status,
      seatsTotal: r.seats_total,
      distanceM: r.distance_m,
      durationS: r.duration_s,
      routeEstimated: r.route_estimated,
      plannedAt: r.planned_at ? new Date(r.planned_at) : null,
      startedAt: r.started_at ? new Date(r.started_at) : null,
      campus: { name: r.campus_name, lat: Number(r.campus_lat), lon: Number(r.campus_lon) },
      consumptionLPer100km: r.consumption === null ? null : Number(r.consumption),
      vehicle: r.vehicle_model || r.vehicle_color ? { model: r.vehicle_model, color: r.vehicle_color } : null,
    };
  }

  async members(rideId: string, db: DbOrTx = this.db): Promise<Member[]> {
    const { rows } = await db.execute<{
      user_id: string;
      role: 'driver' | 'passenger';
      status: string;
      first_name: string;
      last_name: string;
      photo_url: string | null;
      home_lat: number | null;
      home_lon: number | null;
      home_address: string | null;
      use_meeting_point: boolean;
      meet_lat: number | null;
      meet_lon: number | null;
      pickup_label: string | null;
      stop_order: number | null;
      eta: Date | null;
      presence_validated_at: Date | null;
      arrived_at: Date | null;
      ended_at: Date | null;
      detour_s: number | null;
      onboard_m: number | null;
    }>(sql`
      SELECT p.user_id, p.role, p.status, u.first_name, u.last_name, u.photo_url,
             ST_Y(u.home_location::geometry) AS home_lat, ST_X(u.home_location::geometry) AS home_lon,
             u.home_address, p.use_meeting_point,
             ST_Y(p.pickup_location::geometry) AS meet_lat, ST_X(p.pickup_location::geometry) AS meet_lon,
             p.pickup_label, p.stop_order, p.eta, p.presence_validated_at, p.arrived_at, p.ended_at, p.detour_s, p.onboard_m
      FROM ride_participants p JOIN users u ON u.id = p.user_id
      WHERE p.ride_id = ${rideId}
      ORDER BY p.role, p.stop_order NULLS LAST, p.user_id`);
    return rows.map((r) => ({
      userId: r.user_id,
      role: r.role,
      status: r.status,
      firstName: r.first_name,
      lastName: r.last_name,
      photoUrl: r.photo_url,
      home: r.home_lat === null || r.home_lon === null ? null : { lat: Number(r.home_lat), lon: Number(r.home_lon) },
      homeLabel: r.home_address,
      useMeetingPoint: r.use_meeting_point,
      meetingPoint: r.meet_lat === null || r.meet_lon === null ? null : { lat: Number(r.meet_lat), lon: Number(r.meet_lon) },
      meetingLabel: r.pickup_label,
      stopOrder: r.stop_order,
      eta: r.eta ? new Date(r.eta) : null,
      presenceValidatedAt: r.presence_validated_at ? new Date(r.presence_validated_at) : null,
      arrivedAt: r.arrived_at ? new Date(r.arrived_at) : null,
      endedAt: r.ended_at ? new Date(r.ended_at) : null,
      detourS: r.detour_s,
      onboardM: r.onboard_m,
    }));
  }

  /** Tracé simplifié (~5 m) pour l'affichage : [lat, lon] dans l'ordre du trajet. */
  async routeGeometry(rideId: string): Promise<[number, number][]> {
    const { rows } = await this.db.execute<{ geojson: string | null }>(sql`
      SELECT ST_AsGeoJSON(ST_Simplify(route::geometry, 0.00005), 6) AS geojson FROM rides WHERE id = ${rideId}`);
    const geojson = rows[0]?.geojson;
    if (!geojson) return [];
    const { coordinates } = JSON.parse(geojson) as { coordinates: [number, number][] };
    return coordinates.map(([lon, lat]) => [lat, lon]);
  }

  async savePlan(
    rideId: string,
    plan: {
      geometry: LatLon[];
      distanceM: number;
      durationS: number;
      estimated: boolean;
      totalCostCents: number | null;
      stops: { userId: string; order: number; eta: Date; onboardM?: number | null; detourS?: number | null }[];
      /** Null : plan provisoire (estimé), à recalculer. */
      now: Date | null;
    },
    tx: Tx,
  ): Promise<void> {
    const line = JSON.stringify({ type: 'LineString', coordinates: plan.geometry.map((p) => [p.lon, p.lat]) });
    await tx.execute(sql`
      UPDATE rides SET route = ST_SetSRID(ST_GeomFromGeoJSON(${line}), 4326)::geography,
        distance_m = ${plan.distanceM}, duration_s = ${plan.durationS},
        route_estimated = ${plan.estimated}, estimated_total_cost_cents = ${plan.totalCostCents},
        planned_at = ${plan.now}
      WHERE id = ${rideId}`);
    await tx
      .update(rideParticipants)
      .set({ stopOrder: null, eta: null, onboardM: null })
      .where(eq(rideParticipants.rideId, rideId));
    for (const stop of plan.stops) {
      await tx
        .update(rideParticipants)
        .set({
          stopOrder: stop.order,
          eta: stop.eta,
          onboardM: stop.onboardM ?? null,
          // Détour réel s'il a pu être calculé ; sinon l'estimation du matching reste.
          ...(stop.detourS != null ? { detourS: stop.detourS } : {}),
        })
        .where(and(eq(rideParticipants.rideId, rideId), eq(rideParticipants.userId, stop.userId)));
    }
  }

  async setPickup(
    rideId: string,
    userId: string,
    pickup: { label: string; point: LatLon } | null,
    db: DbOrTx = this.db,
  ): Promise<void> {
    await db.execute(sql`
      UPDATE ride_participants SET
        use_meeting_point = ${pickup !== null},
        pickup_label = ${pickup?.label ?? null},
        pickup_location = ${pickup ? sql`ST_SetSRID(ST_MakePoint(${pickup.point.lon}, ${pickup.point.lat}), 4326)::geography` : null}
      WHERE ride_id = ${rideId} AND user_id = ${userId}`);
  }

  async declinePendingRequests(rideId: string, tx: Tx): Promise<string[]> {
    const { rows } = await tx.execute<{ user_id: string }>(sql`
      UPDATE ride_participants SET status = 'declined' WHERE ride_id = ${rideId} AND status = 'requested'
      RETURNING user_id`);
    return rows.map((r) => r.user_id);
  }

  async setRideStatus(
    rideId: string,
    status: 'in_progress' | 'completed',
    fields: { startedAt?: Date; endedAt?: Date; finalTotalCostCents?: number | null },
    tx: Tx,
  ): Promise<void> {
    await tx
      .update(rides)
      .set({
        status,
        ...(fields.startedAt ? { startedAt: fields.startedAt } : {}),
        ...(fields.endedAt ? { endedAt: fields.endedAt } : {}),
        ...(fields.finalTotalCostCents !== undefined ? { finalTotalCostCents: fields.finalTotalCostCents } : {}),
      })
      .where(eq(rides.id, rideId));
  }

  async setParticipant(
    rideId: string,
    userId: string,
    fields: {
      status?: 'picked_up' | 'absent' | 'cancelled';
      pickedUpAt?: Date;
      presenceValidatedAt?: Date;
      amountCents?: number;
      cancelledAt?: Date;
      arrivedAt?: Date;
      endedAt?: Date;
    },
    tx: Tx,
  ): Promise<void> {
    await tx
      .update(rideParticipants)
      .set(fields)
      .where(and(eq(rideParticipants.rideId, rideId), eq(rideParticipants.userId, userId)));
  }

  /** Trace réduite pour les litiges (rétention courte, `tracking.traceRetentionDays`). */
  async insertTrace(rideId: string, userId: string, at: Date, point: LatLon): Promise<void> {
    await this.db.execute(sql`
      INSERT INTO position_trace (ride_id, user_id, recorded_at, location)
      VALUES (${rideId}, ${userId}, ${at}, ST_SetSRID(ST_MakePoint(${point.lon}, ${point.lat}), 4326)::geography)
      ON CONFLICT DO NOTHING`);
  }

  async staleInProgress(targetBefore: Date): Promise<string[]> {
    const { rows } = await this.db.execute<{ id: string }>(
      sql`SELECT id FROM rides WHERE status = 'in_progress' AND target_time < ${targetBefore}`,
    );
    return rows.map((r) => r.id);
  }

  async purgeTraces(before: Date): Promise<number> {
    const result = await this.db.execute(sql`DELETE FROM position_trace WHERE recorded_at < ${before}`);
    return result.rowCount ?? 0;
  }

  /** Trajets confirmés à venir où l'utilisateur est accepté. */
  async upcomingConfirmedRides(userId: string, fromDay: string): Promise<string[]> {
    const { rows } = await this.db.execute<{ id: string }>(sql`
      SELECT r.id FROM rides r JOIN ride_participants p ON p.ride_id = r.id
      WHERE p.user_id = ${userId} AND p.status IN ('accepted', 'picked_up')
        AND r.status = 'confirmed' AND r.day >= ${fromDay}`);
    return rows.map((r) => r.id);
  }

  /** Le plan doit être recalculé (arrêts modifiés). */
  async invalidatePlan(rideId: string, db: DbOrTx = this.db): Promise<void> {
    await db.update(rides).set({ plannedAt: null }).where(eq(rides.id, rideId));
  }

  /**
   * Trajets terminés d'un participant (historique), du plus récent au plus ancien, avec ce qu'il
   * a payé (passager) ou reçu (conducteur) une fois la clôture faite.
   */
  async history(userId: string, limit: number): Promise<HistoryRow[]> {
    const { rows } = await this.db.execute<{
      id: string;
      day: string;
      direction: Direction;
      target_time: Date;
      role: 'driver' | 'passenger';
      status: string;
      amount_cents: number | null;
      others: string[] | null;
    }>(sql`
      SELECT r.id, r.day::text AS day, r.direction, r.target_time, p.role, p.status::text AS status,
        CASE WHEN p.role = 'driver'
          THEN (SELECT sum(pay.share_cents)::int FROM payments pay
                WHERE pay.ride_id = r.id AND pay.payee_id = ${userId} AND pay.status = 'paid')
          ELSE (SELECT (pay.share_cents + pay.commission_cents)::int FROM payments pay
                WHERE pay.ride_id = r.id AND pay.payer_id = ${userId} AND pay.status = 'paid')
        END AS amount_cents,
        (SELECT array_agg(u.first_name ORDER BY o.role, u.first_name) FROM ride_participants o
           JOIN users u ON u.id = o.user_id
          WHERE o.ride_id = r.id AND o.user_id <> ${userId} AND o.status IN ('accepted', 'picked_up')
            AND (p.role = 'driver' OR o.role = 'driver')) AS others
      FROM rides r JOIN ride_participants p ON p.ride_id = r.id
      WHERE p.user_id = ${userId} AND r.status = 'completed'
        AND p.status IN ('accepted', 'picked_up', 'absent')
      ORDER BY r.day DESC, r.target_time DESC
      LIMIT ${limit}`);
    return rows.map((r) => ({
      id: r.id,
      day: r.day,
      direction: r.direction,
      time: new Date(r.target_time),
      role: r.role,
      myStatus: r.status,
      amountCents: r.amount_cents,
      with: r.others ?? [],
    }));
  }
}

export interface HistoryRow {
  id: string;
  day: string;
  direction: Direction;
  time: Date;
  role: 'driver' | 'passenger';
  myStatus: string;
  /** Payé (passager) ou reçu (conducteur), null sans paiement (absent, prix indisponible). */
  amountCents: number | null;
  /** Prénoms des personnes acceptées : conducteur ↔ passagers, jamais entre passagers. */
  with: string[];
}
