import { sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import type { DisputeReason, ReliabilityEntry, ReliabilityKind } from './domain.js';

export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;

export interface RideFacts {
  id: string;
  day: string;
  targetTime: Date;
  status: string;
  driverId: string;
  endedAt: Date | null;
}

export interface MemberFacts {
  userId: string;
  role: 'driver' | 'passenger';
  status: string;
  firstName: string;
  photoUrl: string | null;
  cancelledAt: Date | null;
  pickedUpAt: Date | null;
  presenceValidatedAt: Date | null;
}

export interface DisputeRow {
  id: string;
  rideId: string;
  openedBy: string;
  reason: DisputeReason;
  level: number;
  decision: 'upheld' | 'corrected' | 'escalated';
  resolution: string;
  createdAt: Date;
  escalatedAt: Date | null;
}

export interface EventRow extends ReliabilityEntry {
  id: string;
  rideId: string | null;
  rideDay: string | null;
  createdAt: Date;
}

const toDispute = (r: Record<string, unknown>): DisputeRow => ({
  id: r.id as string,
  rideId: r.ride_id as string,
  openedBy: r.opened_by as string,
  reason: r.reason as DisputeReason,
  level: Number(r.level),
  decision: r.decision as DisputeRow['decision'],
  resolution: (r.resolution as string | null) ?? '',
  createdAt: new Date(r.created_at as string),
  escalatedAt: r.escalated_at ? new Date(r.escalated_at as string) : null,
});

/** Score, notes, litiges et signalements (tables de `docs/data-model.sql`). */
export class TrustRepo {
  constructor(private readonly db: Db) {}

  transaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.transaction(fn);
  }

  async ride(rideId: string, db: DbOrTx = this.db): Promise<RideFacts | null> {
    const { rows } = await db.execute<{
      id: string;
      day: string;
      target_time: string;
      status: string;
      driver_id: string;
      ended_at: string | null;
    }>(sql`SELECT id, day::text, target_time, status, driver_id, ended_at FROM rides WHERE id = ${rideId}`);
    const r = rows[0];
    if (!r) return null;
    return {
      id: r.id,
      day: r.day,
      targetTime: new Date(r.target_time),
      status: r.status,
      driverId: r.driver_id,
      endedAt: r.ended_at ? new Date(r.ended_at) : null,
    };
  }

  async members(rideId: string, db: DbOrTx = this.db): Promise<MemberFacts[]> {
    const { rows } = await db.execute<{
      user_id: string;
      role: 'driver' | 'passenger';
      status: string;
      first_name: string;
      photo_url: string | null;
      cancelled_at: string | null;
      picked_up_at: string | null;
      presence_validated_at: string | null;
    }>(sql`
      SELECT p.user_id, p.role, p.status, u.first_name, u.photo_url, p.cancelled_at, p.picked_up_at,
             p.presence_validated_at
      FROM ride_participants p JOIN users u ON u.id = p.user_id
      WHERE p.ride_id = ${rideId}
      ORDER BY p.role, p.user_id`);
    const date = (v: string | null) => (v ? new Date(v) : null);
    return rows.map((r) => ({
      userId: r.user_id,
      role: r.role,
      status: r.status,
      firstName: r.first_name,
      photoUrl: r.photo_url,
      cancelledAt: date(r.cancelled_at),
      pickedUpAt: date(r.picked_up_at),
      presenceValidatedAt: date(r.presence_validated_at),
    }));
  }

  /** Une seule entrée de chaque sorte par personne et par trajet : un rejeu ne compte pas double. */
  async insertEvent(
    userId: string,
    rideId: string | null,
    kind: ReliabilityKind,
    weight: number,
    at: Date,
    db: DbOrTx = this.db,
  ): Promise<boolean> {
    const { rows } = await db.execute<{ id: string }>(sql`
      INSERT INTO reliability_events (user_id, ride_id, kind, weight, created_at)
      VALUES (${userId}, ${rideId}, ${kind}, ${weight}, ${at})
      ON CONFLICT (user_id, ride_id, kind) WHERE ride_id IS NOT NULL AND kind <> 'correction' DO NOTHING
      RETURNING id`);
    return rows.length > 0;
  }

  async entriesSince(userId: string, since: Date, db: DbOrTx = this.db): Promise<ReliabilityEntry[]> {
    const { rows } = await db.execute<{ kind: ReliabilityKind; weight: string }>(sql`
      SELECT kind, weight FROM reliability_events WHERE user_id = ${userId} AND created_at >= ${since}`);
    return rows.map((r) => ({ kind: r.kind, weight: Number(r.weight) }));
  }

  async entriesForRide(userId: string, rideId: string, db: DbOrTx = this.db): Promise<ReliabilityEntry[]> {
    const { rows } = await db.execute<{ kind: ReliabilityKind; weight: string }>(sql`
      SELECT kind, weight FROM reliability_events WHERE user_id = ${userId} AND ride_id = ${rideId}`);
    return rows.map((r) => ({ kind: r.kind, weight: Number(r.weight) }));
  }

  async recentEvents(userId: string, since: Date, limit: number): Promise<EventRow[]> {
    const { rows } = await this.db.execute<{
      id: string;
      ride_id: string | null;
      day: string | null;
      kind: ReliabilityKind;
      weight: string;
      created_at: string;
    }>(sql`
      SELECT e.id, e.ride_id, r.day::text AS day, e.kind, e.weight, e.created_at
      FROM reliability_events e LEFT JOIN rides r ON r.id = e.ride_id
      WHERE e.user_id = ${userId} AND e.created_at >= ${since} AND e.kind <> 'completed'
      ORDER BY e.created_at DESC LIMIT ${limit}`);
    return rows.map((r) => ({
      id: r.id,
      rideId: r.ride_id,
      rideDay: r.day,
      kind: r.kind,
      weight: Number(r.weight),
      createdAt: new Date(r.created_at),
    }));
  }

  async starsSince(userId: string, since: Date, db: DbOrTx = this.db): Promise<number[]> {
    const { rows } = await db.execute<{ stars: number }>(sql`
      SELECT stars FROM ratings WHERE rated_id = ${userId} AND created_at >= ${since}`);
    return rows.map((r) => Number(r.stars));
  }

  /** Verrou de la ligne : deux recalculs simultanés du même score ne s'écrasent pas. */
  async lockUser(userId: string, db: DbOrTx): Promise<void> {
    await db.execute(sql`SELECT 1 FROM users WHERE id = ${userId} FOR UPDATE`);
  }

  /** Date de la pénalité corrigée : la correction sort de la fenêtre du score en même temps qu'elle. */
  async penaltyDate(userId: string, rideId: string, kinds: readonly ReliabilityKind[], db: DbOrTx): Promise<Date | null> {
    const { rows } = await db.execute<{ at: string | null }>(sql`
      SELECT min(created_at) AS at FROM reliability_events
      WHERE user_id = ${userId} AND ride_id = ${rideId} AND kind IN (${sql.join(
        kinds.map((k) => sql`${k}`),
        sql`, `,
      )})`);
    return rows[0]?.at ? new Date(rows[0].at) : null;
  }

  /** Personnes dont une entrée ou une note vient de sortir de la fenêtre du score. */
  async usersLeavingWindow(from: Date, to: Date): Promise<string[]> {
    const { rows } = await this.db.execute<{ user_id: string }>(sql`
      SELECT user_id FROM reliability_events WHERE created_at >= ${from} AND created_at < ${to}
      UNION SELECT rated_id FROM ratings WHERE created_at >= ${from} AND created_at < ${to}`);
    return rows.map((r) => r.user_id);
  }

  /** Verrou par auteur : le quota de signalements tient avec des requêtes simultanées. */
  async lockReporter(reporterId: string, db: DbOrTx): Promise<void> {
    await db.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${`report:${reporterId}`}))`);
  }

  async setScore(userId: string, score: number, db: DbOrTx = this.db): Promise<void> {
    await db.execute(sql`UPDATE users SET reliability_score = ${score} WHERE id = ${userId}`);
  }

  async insertRating(rideId: string, raterId: string, ratedId: string, stars: number, at: Date, db: DbOrTx = this.db) {
    const { rows } = await db.execute<{ stars: number }>(sql`
      INSERT INTO ratings (ride_id, rater_id, rated_id, stars, created_at)
      VALUES (${rideId}, ${raterId}, ${ratedId}, ${stars}, ${at})
      ON CONFLICT DO NOTHING RETURNING stars`);
    return rows.length > 0;
  }

  async ratingsBy(rideId: string, raterId: string): Promise<Map<string, number>> {
    const { rows } = await this.db.execute<{ rated_id: string; stars: number }>(sql`
      SELECT rated_id, stars FROM ratings WHERE ride_id = ${rideId} AND rater_id = ${raterId}`);
    return new Map(rows.map((r) => [r.rated_id, Number(r.stars)]));
  }

  async insertDispute(
    input: { rideId: string; openedBy: string; reason: DisputeReason; message: string | null; level: number; decision: string; resolution: string; at: Date },
    db: DbOrTx = this.db,
  ): Promise<DisputeRow | null> {
    const { rows } = await db.execute(sql`
      INSERT INTO disputes (ride_id, opened_by, reason, message, level, decision, resolution, created_at, escalated_at)
      VALUES (${input.rideId}, ${input.openedBy}, ${input.reason}, ${input.message}, ${input.level}, ${input.decision},
              ${input.resolution}, ${input.at}, ${input.level === 2 ? input.at : null})
      ON CONFLICT (ride_id, opened_by, reason) DO NOTHING
      RETURNING *`);
    return rows[0] ? toDispute(rows[0]) : null;
  }

  async dispute(disputeId: string, db: DbOrTx = this.db, lock = false): Promise<DisputeRow | null> {
    const { rows } = await db.execute(
      lock ? sql`SELECT * FROM disputes WHERE id = ${disputeId} FOR UPDATE` : sql`SELECT * FROM disputes WHERE id = ${disputeId}`,
    );
    return rows[0] ? toDispute(rows[0]) : null;
  }

  async disputesFor(rideId: string, userId: string): Promise<DisputeRow[]> {
    const { rows } = await this.db.execute(sql`
      SELECT * FROM disputes WHERE ride_id = ${rideId} AND opened_by = ${userId} ORDER BY created_at`);
    return rows.map(toDispute);
  }

  /** Passage au niveau 2 ; `false` si déjà transmis (rejeu). */
  async escalate(disputeId: string, message: string | null, at: Date, db: DbOrTx = this.db): Promise<boolean> {
    const { rows } = await db.execute<{ id: string }>(sql`
      UPDATE disputes SET level = 2, decision = 'escalated', escalated_at = ${at},
             message = COALESCE(${message}, message)
      WHERE id = ${disputeId} AND level = 1 RETURNING id`);
    return rows.length > 0;
  }

  /** Les deux personnes ont été sur un même trajet (proposé ou non) : seul cas où signaler. */
  async sharedRide(a: string, b: string): Promise<boolean> {
    const { rows } = await this.db.execute(sql`
      SELECT 1 FROM ride_participants x JOIN ride_participants y ON y.ride_id = x.ride_id
      WHERE x.user_id = ${a} AND y.user_id = ${b} LIMIT 1`);
    return rows.length > 0;
  }

  async reportsSince(reporterId: string, since: Date, db: DbOrTx = this.db): Promise<number> {
    const { rows } = await db.execute<{ n: string }>(sql`
      SELECT count(*) AS n FROM reports WHERE reporter_id = ${reporterId} AND created_at >= ${since}`);
    return Number(rows[0]?.n ?? 0);
  }

  async insertReport(
    input: { reporterId: string; targetUserId: string; reason: string; message: string | null; at: Date },
    db: DbOrTx = this.db,
  ) {
    const { rows } = await db.execute<{ id: string }>(sql`
      INSERT INTO reports (reporter_id, target_user_id, reason, message, created_at)
      VALUES (${input.reporterId}, ${input.targetUserId}, ${input.reason}, ${input.message}, ${input.at})
      RETURNING id`);
    return rows[0]!.id;
  }

  async contact(userId: string, db: DbOrTx = this.db): Promise<{ email: string; firstName: string } | null> {
    const { rows } = await db.execute<{ email: string; first_name: string }>(sql`
      SELECT university_email AS email, first_name FROM users WHERE id = ${userId}`);
    return rows[0] ? { email: rows[0].email, firstName: rows[0].first_name } : null;
  }

  async eventCount(userId: string, rideId: string, kinds: readonly ReliabilityKind[]): Promise<number> {
    return (await this.entriesForRide(userId, rideId)).filter((e) => kinds.includes(e.kind)).length;
  }

  async score(userId: string): Promise<number> {
    const { rows } = await this.db.execute<{ s: string }>(sql`SELECT reliability_score AS s FROM users WHERE id = ${userId}`);
    return Number(rows[0]?.s ?? 0);
  }
}
