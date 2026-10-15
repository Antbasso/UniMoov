import { and, asc, eq, gte, lt, sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import { calendarConnections, manualScheduleDays, scheduleSlots } from '../../db/schema.js';
import type { ManualDay } from './domain.js';
import type { DaySlot } from './ics.js';

export type SlotSource = 'calendar' | 'manual';

export class CalendarRepo {
  constructor(private readonly db: Db) {}

  async findConnection(userId: string) {
    const [connection] = await this.db.select().from(calendarConnections).where(eq(calendarConnections.userId, userId));
    return connection;
  }

  async listConnections() {
    return this.db.select().from(calendarConnections);
  }

  async upsertConnection(userId: string, encrypted: Buffer, now: Date) {
    const [connection] = await this.db
      .insert(calendarConnections)
      .values({ userId, provider: 'ics', encryptedCredentials: encrypted, consentedAt: now, lastSyncedAt: now })
      .onConflictDoUpdate({
        target: calendarConnections.userId,
        set: { encryptedCredentials: encrypted, consentedAt: now, lastSyncedAt: now, lastError: null },
      })
      .returning();
    return connection!;
  }

  async markSync(userId: string, now: Date, error: string | null): Promise<void> {
    await this.db
      .update(calendarConnections)
      .set(error ? { lastError: error } : { lastSyncedAt: now, lastError: null })
      .where(eq(calendarConnections.userId, userId));
  }

  async deleteConnection(userId: string, connectionId: string): Promise<boolean> {
    const deleted = await this.db
      .delete(calendarConnections)
      .where(and(eq(calendarConnections.id, connectionId), eq(calendarConnections.userId, userId)))
      .returning({ id: calendarConnections.id });
    return deleted.length > 0;
  }

  async getManual(userId: string): Promise<ManualDay[]> {
    const rows = await this.db
      .select()
      .from(manualScheduleDays)
      .where(eq(manualScheduleDays.userId, userId))
      .orderBy(asc(manualScheduleDays.weekday));
    return rows.map((r) => ({ weekday: r.weekday, startTime: r.startTime.slice(0, 5), endTime: r.endTime.slice(0, 5) }));
  }

  async usersWithManual(): Promise<string[]> {
    const rows = await this.db.selectDistinct({ userId: manualScheduleDays.userId }).from(manualScheduleDays);
    return rows.map((r) => r.userId);
  }

  async replaceManual(userId: string, days: readonly ManualDay[]): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx.delete(manualScheduleDays).where(eq(manualScheduleDays.userId, userId));
      if (days.length > 0) await tx.insert(manualScheduleDays).values(days.map((d) => ({ userId, ...d })));
    });
  }

  /** Créneaux effectifs : agenda connecté s'il existe, sinon semaine type. */
  async effectiveSlots(userId: string, fromDay: string, toDayExclusive: string): Promise<DaySlot[]> {
    const rows = await this.db
      .select({ day: scheduleSlots.day, start: scheduleSlots.startAt, end: scheduleSlots.endAt })
      .from(scheduleSlots)
      .where(
        and(
          eq(scheduleSlots.userId, userId),
          gte(scheduleSlots.day, fromDay),
          lt(scheduleSlots.day, toDayExclusive),
          sql`${scheduleSlots.source} = CASE WHEN EXISTS (
            SELECT 1 FROM calendar_connections c WHERE c.user_id = ${userId}
          ) THEN 'calendar' ELSE 'manual' END`,
        ),
      )
      .orderBy(asc(scheduleSlots.day));
    return rows;
  }

  /** Remplace les créneaux d'une source sur [fromDay, toDay[ ; le passé n'est jamais touché. */
  async replaceSlots(
    userId: string,
    source: SlotSource,
    fromDay: string,
    toDayExclusive: string,
    slots: readonly DaySlot[],
  ): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx
        .delete(scheduleSlots)
        .where(
          and(
            eq(scheduleSlots.userId, userId),
            eq(scheduleSlots.source, source),
            gte(scheduleSlots.day, fromDay),
            lt(scheduleSlots.day, toDayExclusive),
          ),
        );
      const inRange = slots.filter((s) => s.day >= fromDay && s.day < toDayExclusive);
      if (inRange.length > 0) {
        await tx
          .insert(scheduleSlots)
          .values(inRange.map((s) => ({ userId, source, day: s.day, startAt: s.start, endAt: s.end })));
      }
    });
  }

  async deleteSlots(userId: string, source: SlotSource): Promise<void> {
    await this.db.delete(scheduleSlots).where(and(eq(scheduleSlots.userId, userId), eq(scheduleSlots.source, source)));
  }
}
