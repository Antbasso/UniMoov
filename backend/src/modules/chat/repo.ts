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

export interface MessageRow {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  createdAt: Date;
}

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
        l.id AS l_id, l.sender_id AS l_sender, l.body AS l_body, l.created_at AS l_created
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
        ? { id: r.l_id as string, conversationId: r.id as string, senderId: r.l_sender as string, body: r.l_body as string, createdAt: new Date(r.l_created as string) }
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

  async insertMessage(conversationId: string, senderId: string, body: string, at: Date, db: DbOrTx = this.db): Promise<MessageRow> {
    const { rows } = await db.execute(sql`
      INSERT INTO messages (conversation_id, sender_id, body, created_at) VALUES (${conversationId}, ${senderId}, ${body}, ${at})
      RETURNING *`);
    await db.execute(sql`UPDATE conversations SET last_message_at = ${at} WHERE id = ${conversationId}`);
    // Ses propres messages sont lus.
    await this.markRead(conversationId, senderId, at, db);
    return toMessage(rows[0]!);
  }

  async messages(conversationId: string, before: Date | null, limit: number): Promise<MessageRow[]> {
    const { rows } = await this.db.execute(
      before
        ? sql`SELECT * FROM messages WHERE conversation_id = ${conversationId} AND created_at < ${before}
              ORDER BY created_at DESC, id DESC LIMIT ${limit}`
        : sql`SELECT * FROM messages WHERE conversation_id = ${conversationId} ORDER BY created_at DESC, id DESC LIMIT ${limit}`,
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
      ORDER BY u.first_name, u.id LIMIT 200`);
    return rows.map((r) => ({ userId: r.id, firstName: r.first_name, photoUrl: r.photo_url }));
  }

  async sharedRideWithAll(userId: string, others: readonly string[]): Promise<boolean> {
    const known = new Set((await this.contacts(userId)).map((c) => c.userId));
    return others.every((o) => known.has(o));
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

  async setRetention(conversationId: string, archivedAt: Date | null, deleteAfter: Date | null, db: DbOrTx = this.db) {
    await db.execute(sql`UPDATE conversations SET archived_at = ${archivedAt}, delete_after = ${deleteAfter} WHERE id = ${conversationId}`);
  }

  /** Chats de trajet d'un trajet terminé ou annulé, pas encore programmés pour l'archivage. */
  async rideChatsToSchedule(): Promise<{ id: string; status: string; endedAt: Date | null; day: string }[]> {
    const { rows } = await this.db.execute<{ id: string; status: string; ended_at: string | null; day: string }>(sql`
      SELECT c.id, r.status, r.ended_at, r.day::text AS day FROM conversations c JOIN rides r ON r.id = c.ride_id
      WHERE c.kind = 'ride' AND c.delete_after IS NULL AND r.status IN ('completed', 'cancelled')`);
    return rows.map((r) => ({ id: r.id, status: r.status, endedAt: date(r.ended_at), day: r.day }));
  }

  /** Archivage puis suppression (messages compris, par cascade). */
  async applyRetention(now: Date): Promise<{ deleted: number }> {
    const { rows } = await this.db.execute<{ id: string }>(sql`
      DELETE FROM conversations WHERE delete_after IS NOT NULL AND delete_after <= ${now} RETURNING id`);
    return { deleted: rows.length };
  }
}
