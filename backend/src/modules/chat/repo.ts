import { sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';

export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;
export type ConversationKind = 'direct' | 'group' | 'ride';

export interface ConversationRow {
  id: string;
  kind: ConversationKind;
  rideId: string | null;
  title: string | null;
  archivedAt: Date | null;
  deleteAfter: Date | null;
  lastMessageAt: Date | null;
}

export interface MemberRow {
  userId: string;
  firstName: string;
  photoUrl: string | null;
  lastReadAt: Date | null;
}

export interface CarpoolInfo {
  kind: 'offer' | 'request';
  /** Trajet proposé (offre) ; null pour une demande. */
  rideId: string | null;
  day: string;
  direction: 'to_campus' | 'from_campus';
  /** Heure du trajet proposé (offre). */
  time: Date | null;
  /** Personnes montées grâce à ce message, et dans quelle voiture. */
  joined: { userId: string; firstName: string; rideId: string }[];
}

export interface MessageRow {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  createdAt: Date;
  carpool: CarpoolInfo | null;
  /** Une réaction par personne. */
  reactions: { userId: string; emoji: string }[];
  hasPhoto: boolean;
}

/** Colonnes d'un message, avec sa proposition de covoiturage s'il en porte une. */
const MESSAGE_COLUMNS = sql`m.*, coalesce(cr.target_time, m.carpool_time) AS carpool_when,
  (SELECT coalesce(json_agg(json_build_object('userId', u.id, 'firstName', u.first_name, 'rideId', j.ride_id) ORDER BY j.created_at), '[]'::json)
     FROM carpool_joins j JOIN users u ON u.id = j.user_id WHERE j.message_id = m.id) AS carpool_joined,
  (SELECT coalesce(json_agg(json_build_object('userId', r.user_id, 'emoji', r.emoji) ORDER BY r.created_at, r.user_id), '[]'::json)
     FROM message_reactions r WHERE r.message_id = m.id) AS reactions`;

const date = (v: unknown) => (v ? new Date(v as string) : null);
const toConversation = (r: Record<string, unknown>): ConversationRow => ({
  id: r.id as string,
  kind: r.kind as ConversationKind,
  rideId: (r.ride_id as string | null) ?? null,
  title: (r.title as string | null) ?? null,
  archivedAt: date(r.archived_at),
  deleteAfter: date(r.delete_after),
  lastMessageAt: date(r.last_message_at),
});
const toMessage = (r: Record<string, unknown>): MessageRow => ({
  id: r.id as string,
  conversationId: r.conversation_id as string,
  senderId: r.sender_id as string,
  body: r.body as string,
  createdAt: new Date(r.created_at as string),
  carpool: r.carpool_kind
    ? {
        kind: r.carpool_kind as CarpoolInfo['kind'],
        rideId: (r.carpool_ride_id as string | null) ?? null,
        day: typeof r.carpool_day === 'string' ? r.carpool_day.slice(0, 10) : new Date(r.carpool_day as Date).toISOString().slice(0, 10),
        direction: r.carpool_direction as CarpoolInfo['direction'],
        time: date(r.carpool_when),
        joined: (r.carpool_joined as CarpoolInfo['joined'] | undefined) ?? [],
      }
    : null,
  reactions: (r.reactions as MessageRow['reactions'] | undefined) ?? [],
  hasPhoto: r.has_photo === true,
});

/** Conversations, membres et messages (tables de `docs/data-model.sql`). */
export class ChatRepo {
  constructor(private readonly db: Db) {}

  transaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.transaction(fn);
  }

  async conversation(id: string, db: DbOrTx = this.db, lock = false): Promise<ConversationRow | null> {
    const { rows } = await db.execute(
      lock ? sql`SELECT * FROM conversations WHERE id = ${id} FOR UPDATE` : sql`SELECT * FROM conversations WHERE id = ${id}`,
    );
    return rows[0] ? toConversation(rows[0]) : null;
  }

  async isMember(conversationId: string, userId: string, db: DbOrTx = this.db): Promise<boolean> {
    const { rows } = await db.execute(sql`
      SELECT 1 FROM conversation_members WHERE conversation_id = ${conversationId} AND user_id = ${userId}`);
    return rows.length > 0;
  }

  async members(conversationId: string, db: DbOrTx = this.db): Promise<MemberRow[]> {
    const { rows } = await db.execute<{ user_id: string; first_name: string; photo_url: string | null; last_read_at: string | null }>(sql`
      SELECT m.user_id, u.first_name, u.photo_url, m.last_read_at
      FROM conversation_members m JOIN users u ON u.id = m.user_id
      WHERE m.conversation_id = ${conversationId} ORDER BY u.first_name, m.user_id`);
    return rows.map((r) => ({ userId: r.user_id, firstName: r.first_name, photoUrl: r.photo_url, lastReadAt: date(r.last_read_at) }));
  }

  /** Mes conversations, la plus récente d'abord, avec le nombre de messages non lus. */
  async listFor(userId: string): Promise<(ConversationRow & { unread: number; lastMessage: MessageRow | null })[]> {
    const { rows } = await this.db.execute(sql`
      SELECT c.*,
        (SELECT count(*) FROM messages x WHERE x.conversation_id = c.id AND x.sender_id <> ${userId}
           AND (m.last_read_at IS NULL OR x.created_at > m.last_read_at)) AS unread,
        l.id AS l_id, l.sender_id AS l_sender, l.body AS l_body, l.created_at AS l_created, l.has_photo AS l_photo
      FROM conversation_members m
      JOIN conversations c ON c.id = m.conversation_id
      LEFT JOIN LATERAL (SELECT * FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC, id DESC LIMIT 1) l ON true
      WHERE m.user_id = ${userId}
      ORDER BY coalesce(c.last_message_at, c.created_at) DESC, c.id
      LIMIT 200`);
    return rows.map((r) => ({
      ...toConversation(r),
      unread: Number(r.unread),
      lastMessage: r.l_id
        ? {
            id: r.l_id as string,
            conversationId: r.id as string,
            senderId: r.l_sender as string,
            body: r.l_body as string,
            createdAt: new Date(r.l_created as string),
            carpool: null,
            reactions: [],
            hasPhoto: r.l_photo === true,
          }
        : null,
    }));
  }

  async create(
    input: { kind: ConversationKind; title: string | null; rideId?: string | null; directKey?: string | null; createdBy: string | null; at: Date },
    memberIds: readonly string[],
    db: DbOrTx = this.db,
  ): Promise<string> {
    const { rows } = await db.execute<{ id: string }>(sql`
      INSERT INTO conversations (kind, title, ride_id, direct_key, created_by, created_at)
      VALUES (${input.kind}, ${input.title}, ${input.rideId ?? null}, ${input.directKey ?? null}, ${input.createdBy}, ${input.at})
      RETURNING id`);
    const id = rows[0]!.id;
    await this.addMembers(id, memberIds, input.at, db);
    return id;
  }

  /** Conversation privée de la paire, créée si besoin ; sûr en cas de création simultanée. */
  async upsertDirect(key: string, members: readonly string[], createdBy: string, at: Date): Promise<string> {
    return this.db.transaction(async (tx) => {
      const { rows } = await tx.execute<{ id: string }>(sql`
        INSERT INTO conversations (kind, direct_key, created_by, created_at) VALUES ('direct', ${key}, ${createdBy}, ${at})
        ON CONFLICT (direct_key) WHERE kind = 'direct' DO NOTHING RETURNING id`);
      if (rows[0]) {
        await this.addMembers(rows[0].id, members, at, tx);
        return rows[0].id;
      }
      return (await this.byDirectKey(key, tx))!;
    });
  }

  /** Verrou du trajet : les synchronisations de son chat passent l'une après l'autre. */
  async lockRide(rideId: string, db: DbOrTx): Promise<void> {
    await db.execute(sql`SELECT 1 FROM rides WHERE id = ${rideId} FOR UPDATE`);
  }

  async addMembers(conversationId: string, userIds: readonly string[], at: Date, db: DbOrTx = this.db): Promise<void> {
    for (const userId of userIds) {
      await db.execute(sql`
        INSERT INTO conversation_members (conversation_id, user_id, joined_at) VALUES (${conversationId}, ${userId}, ${at})
        ON CONFLICT DO NOTHING`);
    }
  }

  async removeMembers(conversationId: string, userIds: readonly string[], db: DbOrTx = this.db): Promise<void> {
    for (const userId of userIds) {
      await db.execute(sql`DELETE FROM conversation_members WHERE conversation_id = ${conversationId} AND user_id = ${userId}`);
    }
  }

  async byDirectKey(key: string, db: DbOrTx = this.db): Promise<string | null> {
    const { rows } = await db.execute<{ id: string }>(sql`SELECT id FROM conversations WHERE kind = 'direct' AND direct_key = ${key}`);
    return rows[0]?.id ?? null;
  }

  async byRide(rideId: string, db: DbOrTx = this.db): Promise<ConversationRow | null> {
    const { rows } = await db.execute(sql`SELECT * FROM conversations WHERE kind = 'ride' AND ride_id = ${rideId}`);
    return rows[0] ? toConversation(rows[0]) : null;
  }

  async insertMessage(
    conversationId: string,
    senderId: string,
    body: string,
    at: Date,
    db: DbOrTx = this.db,
    carpool: { kind: 'offer' | 'request'; rideId: string | null; day: string; direction: string; time?: Date | null } | null = null,
    photo: { contentType: string; data: Buffer } | null = null,
  ): Promise<MessageRow> {
    const { rows } = await db.execute<{ id: string }>(sql`
      INSERT INTO messages (conversation_id, sender_id, body, created_at, carpool_kind, carpool_ride_id, carpool_day, carpool_direction, carpool_time, has_photo)
      VALUES (${conversationId}, ${senderId}, ${body}, ${at}, ${carpool?.kind ?? null}, ${carpool?.rideId ?? null},
              ${carpool?.day ?? null}, ${carpool?.direction ?? null}, ${carpool?.time ?? null}, ${photo !== null})
      RETURNING id`);
    if (photo) {
      await db.execute(sql`
        INSERT INTO message_photos (message_id, content_type, data) VALUES (${rows[0]!.id}, ${photo.contentType}, ${photo.data})`);
    }
    await db.execute(sql`UPDATE conversations SET last_message_at = ${at} WHERE id = ${conversationId}`);
    // Ses propres messages sont lus.
    await this.markRead(conversationId, senderId, at, db);
    return (await this.message(conversationId, rows[0]!.id, db))!;
  }

  async message(conversationId: string, messageId: string, db: DbOrTx = this.db): Promise<MessageRow | undefined> {
    const { rows } = await db.execute(sql`
      SELECT ${MESSAGE_COLUMNS} FROM messages m LEFT JOIN rides cr ON cr.id = m.carpool_ride_id
      WHERE m.conversation_id = ${conversationId} AND m.id = ${messageId}`);
    return rows[0] ? toMessage(rows[0]) : undefined;
  }

  /** Ma réaction à un message : remplacée, ou retirée (`null`). */
  async setReaction(messageId: string, userId: string, emoji: string | null, at: Date): Promise<void> {
    await this.db.execute(
      emoji === null
        ? sql`DELETE FROM message_reactions WHERE message_id = ${messageId} AND user_id = ${userId}`
        : sql`INSERT INTO message_reactions (message_id, user_id, emoji, created_at) VALUES (${messageId}, ${userId}, ${emoji}, ${at})
              ON CONFLICT (message_id, user_id) DO UPDATE SET emoji = excluded.emoji, created_at = excluded.created_at`,
    );
  }

  async photo(conversationId: string, messageId: string): Promise<{ contentType: string; data: Buffer } | undefined> {
    const { rows } = await this.db.execute<{ content_type: string; data: Buffer }>(sql`
      SELECT p.content_type, p.data FROM message_photos p JOIN messages m ON m.id = p.message_id
      WHERE m.conversation_id = ${conversationId} AND p.message_id = ${messageId}`);
    const r = rows[0];
    return r ? { contentType: r.content_type, data: Buffer.from(r.data) } : undefined;
  }

  async addCarpoolJoin(messageId: string, userId: string, rideId: string, db: DbOrTx = this.db): Promise<void> {
    await db.execute(sql`
      INSERT INTO carpool_joins (message_id, user_id, ride_id) VALUES (${messageId}, ${userId}, ${rideId})
      ON CONFLICT DO NOTHING`);
  }

  /**
   * Trajet ouvert (proposé ou confirmé, pas encore parti) que cette personne conduit et a
   * accepté, à partir d'aujourd'hui : par identifiant (offre) ou par jour et sens (demande).
   */
  async drivenOpenRide(
    driverId: string,
    where: { rideId: string } | { day: string; direction: string },
    today: string,
  ): Promise<{ id: string; day: string; direction: 'to_campus' | 'from_campus' } | undefined> {
    const filter = 'rideId' in where ? sql`r.id = ${where.rideId}` : sql`r.day = ${where.day} AND r.direction = ${where.direction}`;
    const { rows } = await this.db.execute<{ id: string; day: string; direction: 'to_campus' | 'from_campus' }>(sql`
      SELECT r.id, r.day::text AS day, r.direction FROM rides r
      JOIN ride_participants p ON p.ride_id = r.id AND p.user_id = ${driverId} AND p.role = 'driver' AND p.status = 'accepted'
      WHERE ${filter} AND r.status IN ('proposed', 'confirmed') AND r.day >= ${today}
      ORDER BY r.target_time LIMIT 1`);
    return rows[0];
  }

  /** Curseur (date, identifiant) : aucun message sauté à horodatage égal. */
  async messages(conversationId: string, before: { at: Date; id: string | null } | null, limit: number): Promise<MessageRow[]> {
    const { rows } = await this.db.execute(
      before
        ? sql`SELECT ${MESSAGE_COLUMNS} FROM messages m LEFT JOIN rides cr ON cr.id = m.carpool_ride_id
              WHERE m.conversation_id = ${conversationId}
                AND (m.created_at, m.id) < (${before.at}, ${before.id ?? 'ffffffff-ffff-ffff-ffff-ffffffffffff'}::uuid)
              ORDER BY m.created_at DESC, m.id DESC LIMIT ${limit}`
        : sql`SELECT ${MESSAGE_COLUMNS} FROM messages m LEFT JOIN rides cr ON cr.id = m.carpool_ride_id
              WHERE m.conversation_id = ${conversationId} ORDER BY m.created_at DESC, m.id DESC LIMIT ${limit}`,
    );
    return rows.map(toMessage);
  }

  async markRead(conversationId: string, userId: string, at: Date, db: DbOrTx = this.db): Promise<void> {
    await db.execute(sql`
      UPDATE conversation_members SET last_read_at = greatest(coalesce(last_read_at, ${at}), ${at})
      WHERE conversation_id = ${conversationId} AND user_id = ${userId}`);
  }

  /** Personnes avec qui j'ai partagé un trajet (proposé ou confirmé) : seules joignables. */
  async contacts(userId: string): Promise<{ userId: string; firstName: string; photoUrl: string | null }[]> {
    const { rows } = await this.db.execute<{ id: string; first_name: string; photo_url: string | null }>(sql`
      SELECT DISTINCT u.id, u.first_name, u.photo_url
      FROM ride_participants x JOIN ride_participants y ON y.ride_id = x.ride_id
      JOIN users u ON u.id = y.user_id
      WHERE x.user_id = ${userId} AND y.user_id <> ${userId} AND u.deleted_at IS NULL
        -- Engagés ou proposés ensemble : pas quelqu'un qui a refusé ou annulé.
        AND x.status IN ('proposed', 'accepted', 'picked_up', 'absent')
        AND y.status IN ('proposed', 'accepted', 'picked_up', 'absent')
      ORDER BY u.first_name, u.id LIMIT 200`);
    return rows.map((r) => ({ userId: r.id, firstName: r.first_name, photoUrl: r.photo_url }));
  }

  /** Même règle que `contacts`, vérifiée directement (sans la limite d'affichage de la liste). */
  async sharedRideWithAll(userId: string, others: readonly string[]): Promise<boolean> {
    if (others.length === 0) return true;
    const { rows } = await this.db.execute<{ n: number }>(sql`
      SELECT count(DISTINCT y.user_id)::int AS n
      FROM ride_participants x JOIN ride_participants y ON y.ride_id = x.ride_id
      JOIN users u ON u.id = y.user_id
      WHERE x.user_id = ${userId} AND u.deleted_at IS NULL
        AND y.user_id IN (${sql.join(
          others.map((o) => sql`${o}`),
          sql`, `,
        )})
        AND x.status IN ('proposed', 'accepted', 'picked_up', 'absent')
        AND y.status IN ('proposed', 'accepted', 'picked_up', 'absent')`);
    return (rows[0]?.n ?? 0) === new Set(others).size;
  }

  /** Personnes acceptées d'un trajet confirmé, en cours ou terminé (membres du chat de trajet). */
  async rideMembers(rideId: string, db: DbOrTx = this.db): Promise<{ status: string; endedAt: Date | null; members: string[] } | null> {
    const { rows } = await db.execute<{ status: string; ended_at: string | null; members: string[] | null }>(sql`
      SELECT r.status, r.ended_at,
        array_remove(array_agg(p.user_id) FILTER (WHERE p.status IN ('accepted', 'picked_up', 'absent')), NULL) AS members
      FROM rides r LEFT JOIN ride_participants p ON p.ride_id = r.id
      WHERE r.id = ${rideId} GROUP BY r.id`);
    const r = rows[0];
    return r ? { status: r.status, endedAt: date(r.ended_at), members: r.members ?? [] } : null;
  }

  async rideInfo(rideId: string): Promise<{ day: string; direction: 'to_campus' | 'from_campus' } | null> {
    const { rows } = await this.db.execute<{ day: string; direction: 'to_campus' | 'from_campus' }>(sql`
      SELECT day::text AS day, direction FROM rides WHERE id = ${rideId}`);
    return rows[0] ?? null;
  }

  async setRetention(conversationId: string, archivedAt: Date | null, deleteAfter: Date | null, db: DbOrTx = this.db) {
    await db.execute(sql`UPDATE conversations SET archived_at = ${archivedAt}, delete_after = ${deleteAfter} WHERE id = ${conversationId}`);
  }

  /**
   * Chats de trajet à programmer pour l'archivage : trajet terminé, annulé, ou confirmé mais
   * jamais parti (heure dépassée de `staleBefore`), qui sinon garderait son chat pour toujours.
   */
  async rideChatsToSchedule(staleBefore: Date): Promise<{ id: string; endedAt: Date | null; targetTime: Date }[]> {
    const { rows } = await this.db.execute<{ id: string; ended_at: string | null; target_time: string }>(sql`
      SELECT c.id, r.ended_at, r.target_time FROM conversations c JOIN rides r ON r.id = c.ride_id
      WHERE c.kind = 'ride' AND c.delete_after IS NULL
        AND (r.status IN ('completed', 'cancelled') OR (r.status = 'confirmed' AND r.target_time < ${staleBefore}))`);
    return rows.map((r) => ({ id: r.id, endedAt: date(r.ended_at), targetTime: new Date(r.target_time) }));
  }

  /** Trajets confirmés ou en cours sans chat (confirmés avant la messagerie, échec ponctuel). */
  async ridesMissingChat(): Promise<string[]> {
    const { rows } = await this.db.execute<{ id: string }>(sql`
      SELECT r.id FROM rides r WHERE r.status IN ('confirmed', 'in_progress')
        AND NOT EXISTS (SELECT 1 FROM conversations c WHERE c.kind = 'ride' AND c.ride_id = r.id)`);
    return rows.map((r) => r.id);
  }

  /** Archivage puis suppression (messages compris, par cascade). */
  async applyRetention(now: Date): Promise<{ deleted: number }> {
    const { rows } = await this.db.execute<{ id: string }>(sql`
      DELETE FROM conversations WHERE delete_after IS NOT NULL AND delete_after <= ${now} RETURNING id`);
    return { deleted: rows.length };
  }
}
