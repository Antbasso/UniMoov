import { PgBoss } from 'pg-boss';
import type { FastifyBaseLogger } from 'fastify';
import type { CalendarService } from './modules/calendar/service.js';
import type { MatchingService } from './modules/matching/service.js';
import type { RideLifecycle } from './modules/rides/lifecycle.js';
import { addDaysIso, isoWeekOf, parisDateOf } from './shared/time.js';

/**
 * Tâches planifiées dans PostgreSQL (pg-boss, pas de Redis) :
 * - chaque nuit, resynchronisation des agendas ICS ;
 * - chaque vendredi soir, semaines types prolongées puis propositions de la semaine suivante ;
 * - chaque heure, trajets oubliés « en cours » clôturés ;
 * - chaque nuit, traces de position plus anciennes que `tracking.traceRetentionDays` supprimées.
 */
export async function startJobs(
  databaseUrl: string,
  services: { calendar: CalendarService; matching: MatchingService; lifecycle: RideLifecycle },
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
  await boss.schedule('stale-rides', '0 * * * *', null, { tz: 'Europe/Paris' });
  await boss.schedule('trace-purge', '30 4 * * *', null, { tz: 'Europe/Paris' });
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
    log.info({ week: nextWeek }, 'weekly matching done');
  });

  await boss.work('stale-rides', async () => {
    const closed = await services.lifecycle.closeStale();
    if (closed > 0) log.info({ closed }, 'stale rides closed');
  });
  await boss.work('trace-purge', async () => {
    const deleted = await services.lifecycle.purgeTraces();
    log.info({ deleted }, 'position traces purged');
  });

  return () => boss.stop();
}
