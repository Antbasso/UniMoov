import { sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';

type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
type Row = Record<string, unknown>;

/** Export (RGPD, droit d'accès et portabilité) et suppression du compte. */
export class AccountRepo {
  constructor(private readonly db: Db) {}

  /** Trajet en cours où la personne est encore à bord ou attendue. */
  async hasRideInProgress(userId: string): Promise<boolean> {
    const { rows } = await this.db.execute(sql`
      SELECT 1 FROM ride_participants rp JOIN rides r ON r.id = rp.ride_id
      WHERE rp.user_id = ${userId} AND r.status = 'in_progress' AND rp.status IN ('accepted', 'picked_up')
      LIMIT 1`);
    return rows.length > 0;
  }

  async walletCents(userId: string): Promise<{ balanceCents: number; heldCents: number }> {
    const { rows } = await this.db.execute<{ balance_cents: number; held_cents: number }>(sql`
      SELECT balance_cents, held_cents FROM wallets WHERE user_id = ${userId}`);
    return { balanceCents: rows[0]?.balance_cents ?? 0, heldCents: rows[0]?.held_cents ?? 0 };
  }

  /** Trajets à venir encore ouverts : proposés ou acceptés. */
  async upcomingParticipations(userId: string, now: Date): Promise<{ rideId: string; status: string }[]> {
    const { rows } = await this.db.execute<{ ride_id: string; status: string }>(sql`
      SELECT rp.ride_id, rp.status FROM ride_participants rp JOIN rides r ON r.id = rp.ride_id
      WHERE rp.user_id = ${userId} AND r.status IN ('proposed', 'confirmed') AND r.target_time > ${now}
        AND rp.status IN ('proposed', 'accepted')
      ORDER BY r.target_time`);
    return rows.map((r) => ({ rideId: r.ride_id, status: r.status }));
  }

  /** Toutes les données de la personne, sans secret (mot de passe, lien d'agenda, jetons). */
  async export(userId: string): Promise<Record<string, unknown>> {
    const all = async (query: ReturnType<typeof sql>): Promise<Row[]> => (await this.db.execute<Row>(query)).rows;
    const [profile] = await all(sql`
      SELECT u.university_email AS "universityEmail", u.first_name AS "firstName", u.last_name AS "lastName",
             u.photo_url AS "photoUrl", u.home_address AS "homeAddress",
             ST_Y(u.home_location::geometry) AS "homeLat", ST_X(u.home_location::geometry) AS "homeLon",
             u.home_sector AS "homeSector", c.name AS campus, u.role_mode AS "roleMode",
             u.default_nav_app AS "defaultNavApp", u.reliability_score::float AS "reliabilityScore",
             u.onboarding_steps AS "onboardingSteps", u.created_at AS "createdAt"
      FROM users u LEFT JOIN campuses c ON c.id = u.campus_id WHERE u.id = ${userId}`);
    return {
      profile,
      vehicle:
        (
          await all(sql`
            SELECT consumption_l_per_100km::float AS "consumptionLPer100km", default_seats AS "defaultSeats",
                   max_detour_minutes AS "maxDetourMinutes"
            FROM vehicles WHERE user_id = ${userId}`)
        )[0] ?? null,
      pauses: await all(sql`
        SELECT starts_on AS "startsOn", ends_on AS "endsOn" FROM pauses WHERE user_id = ${userId} ORDER BY starts_on`),
      calendarConnections: await all(sql`
        SELECT provider, consented_at AS "consentedAt", last_synced_at AS "lastSyncedAt"
        FROM calendar_connections WHERE user_id = ${userId}`),
      manualSchedule: await all(sql`
        SELECT weekday, start_time AS "startTime", end_time AS "endTime"
        FROM manual_schedule_days WHERE user_id = ${userId} ORDER BY weekday`),
      scheduleSlots: await all(sql`
        SELECT day, start_at AS "startAt", end_at AS "endAt", source
        FROM schedule_slots WHERE user_id = ${userId} ORDER BY start_at`),
      rides: await all(sql`
        SELECT r.id AS "rideId", r.day, r.direction, r.target_time AS "targetTime", r.status AS "rideStatus",
               rp.role, rp.status, rp.pickup_label AS "pickupLabel", rp.eta, rp.picked_up_at AS "pickedUpAt",
               rp.presence_validated_at AS "presenceValidatedAt", rp.cancelled_at AS "cancelledAt",
               rp.amount_cents AS "amountCents"
        FROM ride_participants rp JOIN rides r ON r.id = rp.ride_id
        WHERE rp.user_id = ${userId} ORDER BY r.target_time`),
      wallet: {
        ...(await this.walletCents(userId)),
        ledger: await all(sql`
          SELECT kind, amount_cents AS "amountCents", ride_id AS "rideId", created_at AS "createdAt"
          FROM wallet_ledger WHERE account = ${`user:${userId}`} ORDER BY created_at, id`),
        topups: await all(sql`
          SELECT amount_cents AS "amountCents", status, created_at AS "createdAt"
          FROM topups WHERE user_id = ${userId} ORDER BY created_at`),
        payouts: await all(sql`
          SELECT amount_cents AS "amountCents", status, created_at AS "createdAt"
          FROM payouts WHERE user_id = ${userId} ORDER BY created_at`),
      },
      payments: await all(sql`
        SELECT ride_id AS "rideId", CASE WHEN payer_id = ${userId} THEN 'paid' ELSE 'received' END AS side,
               share_cents AS "shareCents", commission_cents AS "commissionCents", status, paid_at AS "paidAt"
        FROM payments WHERE payer_id = ${userId} OR payee_id = ${userId} ORDER BY created_at`),
      // Notes reçues sans l'identité de qui note (donnée d'un tiers).
      ratingsGiven: await all(sql`
        SELECT ride_id AS "rideId", stars, comment, created_at AS "createdAt"
        FROM ratings WHERE rater_id = ${userId} ORDER BY created_at`),
      ratingsReceived: await all(sql`
        SELECT ride_id AS "rideId", stars, created_at AS "createdAt"
        FROM ratings WHERE rated_id = ${userId} ORDER BY created_at`),
      reliabilityEvents: await all(sql`
        SELECT kind, weight::float AS weight, ride_id AS "rideId", created_at AS "createdAt"
        FROM reliability_events WHERE user_id = ${userId} ORDER BY created_at`),
      disputes: await all(sql`
        SELECT ride_id AS "rideId", reason, level, decision, message, created_at AS "createdAt"
        FROM disputes WHERE opened_by = ${userId} ORDER BY created_at`),
      reportsFiled: await all(sql`
        SELECT reason, message, created_at AS "createdAt" FROM reports WHERE reporter_id = ${userId} ORDER BY created_at`),
      messagesSent: await all(sql`
        SELECT m.conversation_id AS "conversationId", c.kind AS "conversationKind", m.body, m.created_at AS "createdAt"
        FROM messages m JOIN conversations c ON c.id = m.conversation_id
        WHERE m.sender_id = ${userId} ORDER BY m.created_at`),
      devices: await all(sql`
        SELECT platform, updated_at AS "updatedAt" FROM devices WHERE user_id = ${userId}`),
      notificationPreferences: await all(sql`
        SELECT event_type AS category, push_enabled AS enabled FROM notification_preferences WHERE user_id = ${userId}`),
    };
  }

  /**
   * Suppression : les données personnelles sont effacées ; les trajets, paiements, notes et
   * écritures comptables restent, rattachés à un compte anonyme (comptabilité, litiges).
   */
  async anonymize(userId: string, now: Date): Promise<void> {
    await this.db.transaction(async (tx: Tx) => {
      const { rows } = await tx.execute<{ university_email: string }>(sql`
        SELECT university_email FROM users WHERE id = ${userId} AND deleted_at IS NULL FOR UPDATE`);
      const email = rows[0]?.university_email;
      if (email === undefined) return;
      await tx.execute(sql`DELETE FROM verification_codes WHERE email = ${email}`);
      for (const table of [
        'vehicles',
        'pauses',
        'calendar_connections',
        'schedule_slots',
        'manual_schedule_days',
        'devices',
        'notification_preferences',
        'search_quota',
        'refresh_tokens',
        'ride_reminders',
        'conversation_members',
        'position_trace',
      ]) {
        await tx.execute(sql`DELETE FROM ${sql.identifier(table)} WHERE user_id = ${userId}`);
      }
      await tx.execute(sql`DELETE FROM proposal_declines WHERE user_id = ${userId} OR other_user_id = ${userId}`);
      await tx.execute(sql`DELETE FROM messages WHERE sender_id = ${userId}`);
      await tx.execute(sql`UPDATE ratings SET comment = NULL WHERE rater_id = ${userId}`);
      await tx.execute(sql`UPDATE disputes SET message = NULL WHERE opened_by = ${userId}`);
      await tx.execute(sql`UPDATE reports SET message = NULL WHERE reporter_id = ${userId}`);
      // Filet de sécurité : rien d'encore ouvert ne reste à son nom.
      await tx.execute(sql`
        UPDATE rides SET status = 'cancelled' FROM ride_participants rp
        WHERE rp.ride_id = rides.id AND rp.user_id = ${userId} AND rp.role = 'driver'
          AND rides.status IN ('proposed', 'confirmed')`);
      await tx.execute(sql`
        UPDATE ride_participants rp SET status = 'cancelled', cancelled_at = ${now}
        FROM rides r WHERE r.id = rp.ride_id AND r.status IN ('proposed', 'confirmed', 'cancelled')
          AND rp.status IN ('proposed', 'accepted')
          AND (rp.user_id = ${userId} OR r.driver_id = ${userId})`);
      await tx.execute(sql`
        UPDATE ride_participants SET pickup_label = NULL, pickup_location = NULL WHERE user_id = ${userId}`);
      await tx.execute(sql`
        UPDATE users SET university_email = ${`supprime-${userId}@invalid`}, password_hash = NULL,
          first_name = 'Ancien membre', last_name = '', photo_url = NULL, home_address = NULL,
          home_location = NULL, home_sector = NULL, default_nav_app = NULL, paused_until = NULL,
          onboarding_steps = '{}'::jsonb, deleted_at = ${now}
        WHERE id = ${userId}`);
    });
  }
}
