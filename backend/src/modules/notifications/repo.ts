import { sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';

export type Category = 'match' | 'ride_update' | 'ride_reminder' | 'chat';
export const CATEGORIES: readonly Category[] = ['match', 'ride_update', 'ride_reminder', 'chat'];

/** Appareils, préférences et rappels envoyés. */
export class NotificationsRepo {
  constructor(private readonly db: Db) {}

  /** Un jeton appartient au dernier compte connecté sur l'appareil. */
  async upsertDevice(userId: string, platform: string, token: string, at: Date): Promise<void> {
    await this.db.execute(sql`
      INSERT INTO devices (user_id, platform, push_token, updated_at) VALUES (${userId}, ${platform}, ${token}, ${at})
      ON CONFLICT (push_token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = EXCLUDED.updated_at`);
  }

  async deleteDevice(userId: string, token: string): Promise<void> {
    await this.db.execute(sql`DELETE FROM devices WHERE user_id = ${userId} AND push_token = ${token}`);
  }

  async deleteTokens(tokens: readonly string[]): Promise<void> {
    for (const token of tokens) await this.db.execute(sql`DELETE FROM devices WHERE push_token = ${token}`);
  }

  /** Jetons des personnes qui n'ont pas coupé cette catégorie (pas de ligne = activé, §11). */
  async tokensFor(userIds: readonly string[], category: Category): Promise<string[]> {
    if (userIds.length === 0) return [];
    const { rows } = await this.db.execute<{ push_token: string }>(sql`
      SELECT d.push_token FROM devices d
      WHERE d.user_id IN (${sql.join(
        userIds.map((id) => sql`${id}`),
        sql`, `,
      )})
        AND NOT EXISTS (SELECT 1 FROM notification_preferences p
                        WHERE p.user_id = d.user_id AND p.event_type = ${category} AND NOT p.push_enabled)`);
    return rows.map((r) => r.push_token);
  }

  async preferences(userId: string): Promise<Record<Category, boolean>> {
    const { rows } = await this.db.execute<{ event_type: Category; push_enabled: boolean }>(sql`
      SELECT event_type, push_enabled FROM notification_preferences WHERE user_id = ${userId}`);
    const prefs = Object.fromEntries(CATEGORIES.map((c) => [c, true])) as Record<Category, boolean>;
    for (const r of rows) prefs[r.event_type] = r.push_enabled;
    return prefs;
  }

  async setPreference(userId: string, category: Category, enabled: boolean): Promise<void> {
    await this.db.execute(sql`
      INSERT INTO notification_preferences (user_id, event_type, push_enabled) VALUES (${userId}, ${category}, ${enabled})
      ON CONFLICT (user_id, event_type) DO UPDATE SET push_enabled = EXCLUDED.push_enabled`);
  }

  /**
   * Personnes d'un trajet confirmé dont le départ tombe dans la fenêtre, pas encore rappelées.
   * Départ : heure de passage chez le conducteur à l'aller, heure cible au retour.
   */
  async dueReminders(from: Date, to: Date): Promise<{ rideId: string; userId: string; departure: Date }[]> {
    const { rows } = await this.db.execute<{ ride_id: string; user_id: string; departure: string }>(sql`
      WITH ride_departure AS (
        SELECT r.id,
          CASE WHEN r.direction = 'to_campus'
            THEN coalesce(d.eta, r.target_time - make_interval(secs => coalesce(r.duration_s, 0)))
            ELSE r.target_time END AS departure
        FROM rides r JOIN ride_participants d ON d.ride_id = r.id AND d.role = 'driver'
        WHERE r.status = 'confirmed'
      )
      SELECT rd.id AS ride_id, p.user_id, rd.departure
      FROM ride_departure rd JOIN ride_participants p ON p.ride_id = rd.id AND p.status = 'accepted'
      WHERE rd.departure > ${from} AND rd.departure <= ${to}
        AND NOT EXISTS (SELECT 1 FROM ride_reminders x WHERE x.ride_id = rd.id AND x.user_id = p.user_id)`);
    return rows.map((r) => ({ rideId: r.ride_id, userId: r.user_id, departure: new Date(r.departure) }));
  }

  async unmarkReminded(rideId: string, userId: string): Promise<void> {
    await this.db.execute(sql`DELETE FROM ride_reminders WHERE ride_id = ${rideId} AND user_id = ${userId}`);
  }

  /** Personnes ayant au moins une proposition à traiter sur ces jours. */
  async usersWithProposals(fromDay: string, toDay: string): Promise<string[]> {
    const { rows } = await this.db.execute<{ user_id: string }>(sql`
      SELECT DISTINCT p.user_id FROM ride_participants p JOIN rides r ON r.id = p.ride_id
      WHERE r.day BETWEEN ${fromDay} AND ${toDay} AND p.status = 'proposed' AND r.status = 'proposed'`);
    return rows.map((r) => r.user_id);
  }

  /** `false` si déjà marqué (deux tâches simultanées : un seul rappel). */
  async markReminded(rideId: string, userId: string, at: Date): Promise<boolean> {
    const { rows } = await this.db.execute(sql`
      INSERT INTO ride_reminders (ride_id, user_id, sent_at) VALUES (${rideId}, ${userId}, ${at})
      ON CONFLICT DO NOTHING RETURNING ride_id`);
    return rows.length > 0;
  }
}
