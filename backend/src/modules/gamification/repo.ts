import { sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import type { RideStats } from './domain.js';

export interface StatsRow extends RideStats {
  userId: string;
  firstName: string;
  photoUrl: string | null;
  leaderboardVisible: boolean;
}

/**
 * Chiffres de la gamification, tirés des trajets terminés : présent = conducteur accepté ou
 * passager accepté/à bord (pas les absents). `range` : jours du trajet, de `from` inclus à `to` exclu.
 */
export class GamificationRepo {
  constructor(private readonly db: Db) {}

  async stats(who: { userId: string } | { campusId: string }, range?: { from: string; to: string }): Promise<StatsRow[]> {
    const people =
      'userId' in who
        ? sql`u.id = ${who.userId}`
        : sql`u.campus_id = ${who.campusId} AND u.deleted_at IS NULL`;
    const days = range ? sql`AND r.day >= ${range.from} AND r.day < ${range.to}` : sql``;
    const rated = range ? sql`AND rr.day >= ${range.from} AND rr.day < ${range.to}` : sql``;
    const { rows } = await this.db.execute<{
      user_id: string;
      first_name: string;
      photo_url: string | null;
      leaderboard_visible: boolean;
      reliability: string;
      driven: number;
      as_passenger: number;
      carried: number;
      shared_m: number;
      five_stars: number;
      ratings_given: number;
      companions: number;
      best_week: number;
    }>(sql`
      WITH done AS (
        SELECT p.ride_id, p.user_id, p.role, coalesce(p.onboard_m, r.distance_m, 0) AS onboard_m, r.day
        FROM ride_participants p JOIN rides r ON r.id = p.ride_id
        WHERE r.status = 'completed' AND p.status IN ('accepted', 'picked_up') ${days}
      ),
      carried AS (
        SELECT ride_id, count(*)::int AS n, sum(onboard_m)::bigint AS m FROM done WHERE role = 'passenger' GROUP BY ride_id
      ),
      mine AS (
        -- Trajets qui comptent : un conducteur sans passager présent n'a partagé aucun trajet.
        SELECT d.*, c.n, c.m FROM done d LEFT JOIN carried c ON c.ride_id = d.ride_id
        WHERE d.role = 'passenger' OR c.n > 0
      )
      SELECT u.id AS user_id, u.first_name, u.photo_url, u.leaderboard_visible, u.reliability_score AS reliability,
        (SELECT count(*)::int FROM mine WHERE mine.user_id = u.id AND role = 'driver') AS driven,
        (SELECT count(*)::int FROM mine WHERE mine.user_id = u.id AND role = 'passenger') AS as_passenger,
        (SELECT coalesce(sum(n), 0)::int FROM mine WHERE mine.user_id = u.id AND role = 'driver') AS carried,
        (SELECT coalesce(sum(CASE WHEN role = 'driver' THEN m ELSE onboard_m END), 0)::bigint FROM mine WHERE mine.user_id = u.id) AS shared_m,
        (SELECT count(*)::int FROM ratings rt JOIN rides rr ON rr.id = rt.ride_id
          WHERE rt.rated_id = u.id AND rt.stars = 5 ${rated}) AS five_stars,
        (SELECT count(*)::int FROM ratings rt JOIN rides rr ON rr.id = rt.ride_id
          WHERE rt.rater_id = u.id ${rated}) AS ratings_given,
        (SELECT count(DISTINCT o.user_id)::int FROM mine JOIN done o ON o.ride_id = mine.ride_id AND o.user_id <> u.id
          WHERE mine.user_id = u.id) AS companions,
        (SELECT coalesce(max(k), 0)::int FROM (SELECT count(*) AS k FROM mine WHERE mine.user_id = u.id
          GROUP BY date_trunc('week', mine.day)) w) AS best_week
      FROM users u WHERE ${people}`);
    return rows.map((r) => ({
      userId: r.user_id,
      firstName: r.first_name,
      photoUrl: r.photo_url,
      leaderboardVisible: r.leaderboard_visible,
      reliability: Number(r.reliability),
      ridesDriven: r.driven,
      ridesAsPassenger: r.as_passenger,
      passengersCarried: r.carried,
      fiveStarRatings: r.five_stars,
      ratingsGiven: r.ratings_given,
      distinctCompanions: r.companions,
      sharedKm: Number(r.shared_m) / 1000,
      bestWeekRides: r.best_week,
    }));
  }

  /** Ce que la personne a payé (passager) et reçu (conducteur) sur ses trajets terminés. */
  async money(userId: string): Promise<{ paidCents: number; receivedCents: number }> {
    const { rows } = await this.db.execute<{ paid: number; received: number }>(sql`
      SELECT
        (SELECT coalesce(sum(share_cents + commission_cents), 0)::int FROM payments WHERE payer_id = ${userId} AND status = 'paid') AS paid,
        (SELECT coalesce(sum(share_cents), 0)::int FROM payments WHERE payee_id = ${userId} AND status = 'paid') AS received`);
    return { paidCents: rows[0]?.paid ?? 0, receivedCents: rows[0]?.received ?? 0 };
  }

  async campusOf(userId: string): Promise<string | null> {
    const { rows } = await this.db.execute<{ campus_id: string | null }>(sql`SELECT campus_id FROM users WHERE id = ${userId}`);
    return rows[0]?.campus_id ?? null;
  }
}
