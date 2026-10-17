import { PgBoss } from 'pg-boss';
import type { FastifyBaseLogger } from 'fastify';
import type { CalendarService } from './modules/calendar/service.js';
import type { MatchingService } from './modules/matching/service.js';
import type { RideLifecycle } from './modules/rides/lifecycle.js';
import type { TrustService } from './modules/trust/service.js';
import type { ChatService } from './modules/chat/service.js';
import type { NotificationService } from './modules/notifications/service.js';
import type { AccountService } from './modules/account/service.js';
import { addDaysIso, isoWeekOf, parisDateOf, weekDays } from './shared/time.js';

/**
 * Tâches planifiées dans PostgreSQL (pg-boss, pas de Redis) :
 * - chaque nuit, resynchronisation des agendas ICS ;
 * - chaque vendredi soir, semaines types prolongées puis propositions de la semaine suivante ;
 * - chaque heure, trajets oubliés « en cours » clôturés ;
 * - chaque nuit, traces de position plus anciennes que `tracking.traceRetentionDays` supprimées ;
 * - chaque nuit, codes, sessions, créneaux et compteurs périmés effacés (docs/rgpd.md).
 */
export async function startJobs(
  databaseUrl: string,
  services: { calendar: CalendarService; matching: MatchingService; lifecycle: RideLifecycle; trust: TrustService; chat: ChatService; notifications: NotificationService; account: AccountService },
  log: FastifyBaseLogger,
  clock: () => Date = () => new Date(),
): Promise<() => Promise<void>> {
  const boss = new PgBoss(databaseUrl);
  boss.on('error', (error) => log.error({ err: error }, 'job queue error'));
  await boss.start();

  await boss.createQueue('calendar-sync');
  await boss.createQueue('weekly-matching');
  await boss.createQueue('trace-purge');
  await boss.createQueue('stale-rides');
  await boss.createQueue('reliability-refresh');
  await boss.createQueue('chat-retention');
  await boss.createQueue('ride-reminders');
  await boss.createQueue('data-purge');
  await boss.schedule('chat-retention', '45 4 * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('ride-reminders', '*/5 * * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('reliability-refresh', '15 4 * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('stale-rides', '0 * * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('trace-purge', '30 4 * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('data-purge', '50 4 * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('calendar-sync', '0 5 * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('weekly-matching', '0 18 * * 5', null, { tz: 'Europe/Paris' });

  await boss.work('calendar-sync', async () => {
    const result = await services.calendar.syncAll();
    log.info(result, 'calendar sync done');
  });
  await boss.work('weekly-matching', async () => {
    await services.calendar.extendManualAll();
    const nextWeek = isoWeekOf(addDaysIso(parisDateOf(clock()), 7));
    await services.matching.ensureWeek(nextWeek);
    const days = weekDays(nextWeek);
    const notified = await services.notifications.notifyProposalsReady(nextWeek, days[0]!, days[6]!);
    log.info({ week: nextWeek, notified }, 'weekly matching done');
  });

  await boss.work('stale-rides', async () => {
    const closed = await services.lifecycle.closeStale();
    if (closed > 0) log.info({ closed }, 'stale rides closed');
  });
  await boss.work('reliability-refresh', async () => {
    const refreshed = await services.trust.refreshExpired();
    log.info({ refreshed }, 'reliability scores refreshed');
  });
  await boss.work('chat-retention', async () => {
    log.info(await services.chat.applyRetention(), 'chat retention applied');
  });
  await boss.work('ride-reminders', async () => {
    const sent = await services.notifications.sendReminders();
    if (sent > 0) log.info({ sent }, 'ride reminders sent');
  });
  await boss.work('trace-purge', async () => {
    const deleted = await services.lifecycle.purgeTraces();
    log.info({ deleted }, 'position traces purged');
  });

  await boss.work('data-purge', async () => {
    log.info(await services.account.purgeExpired(), 'expired data purged');
  });

  return () => boss.stop();
}
