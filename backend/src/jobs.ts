import { PgBoss } from 'pg-boss';
import type { FastifyBaseLogger } from 'fastify';
import type { CalendarService } from './modules/calendar/service.js';
import type { MatchingService } from './modules/matching/service.js';
import { addDaysIso, isoWeekOf, parisDateOf } from './shared/time.js';

/**
 * Tâches planifiées dans PostgreSQL (pg-boss, pas de Redis) :
 * - chaque nuit, resynchronisation des agendas ICS ;
 * - chaque vendredi soir, semaines types prolongées puis propositions de la semaine suivante.
 */
export async function startJobs(
  databaseUrl: string,
  services: { calendar: CalendarService; matching: MatchingService },
  log: FastifyBaseLogger,
  clock: () => Date = () => new Date(),
): Promise<() => Promise<void>> {
  const boss = new PgBoss(databaseUrl);
  boss.on('error', (error) => log.error({ err: error }, 'job queue error'));
  await boss.start();

  await boss.createQueue('calendar-sync');
  await boss.createQueue('weekly-matching');
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

  return () => boss.stop();
}
