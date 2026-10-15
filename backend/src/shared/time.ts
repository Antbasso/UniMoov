/**
 * Dates et heures du pilote, au fuseau de Paris (toutes les dates sont stockées en UTC).
 * Fonctions pures, sans dépendance : Intl suffit pour le décalage horaire (heure d'été comprise).
 */
export const PARIS_TZ = 'Europe/Paris';

const DAY_MS = 86_400_000;

/** Décalage de Paris par rapport à UTC à un instant donné, en minutes (+60 ou +120). */
export function parisOffsetMinutes(instant: Date): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: PARIS_TZ,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).formatToParts(instant);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour'), get('minute'));
  return Math.round((asUtc - Math.floor(instant.getTime() / 60_000) * 60_000) / 60_000);
}

/** Heure murale de Paris (`AAAA-MM-JJ`, `HH:MM`) → instant UTC. */
export function parisToUtc(isoDate: string, time: string): Date {
  const [y, mo, d] = isoDate.split('-').map(Number) as [number, number, number];
  const [h, mi] = time.split(':').map(Number) as [number, number];
  const naive = Date.UTC(y, mo - 1, d, h, mi);
  // Deux passes : le décalage dépend de l'instant cherché (changement d'heure).
  let guess = naive - parisOffsetMinutes(new Date(naive)) * 60_000;
  guess = naive - parisOffsetMinutes(new Date(guess)) * 60_000;
  return new Date(guess);
}

/** Date de Paris (`AAAA-MM-JJ`) d'un instant. */
export function parisDateOf(instant: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: PARIS_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instant);
}

/** Heure de Paris (`HH:MM`) d'un instant. */
export function parisTimeOf(instant: Date): string {
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: PARIS_TZ,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(instant);
}

export function addDaysIso(isoDate: string, days: number): string {
  const [y, m, d] = isoDate.split('-').map(Number) as [number, number, number];
  return new Date(Date.UTC(y, m - 1, d) + days * DAY_MS).toISOString().slice(0, 10);
}

/** Jour ISO de la semaine : lundi = 1 … dimanche = 7. */
export function isoWeekday(isoDate: string): number {
  const [y, m, d] = isoDate.split('-').map(Number) as [number, number, number];
  return ((new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 6) % 7) + 1;
}

/** Semaine ISO `AAAA-Www` → lundi de cette semaine. */
export function isoWeekMonday(week: string): string {
  const match = /^(\d{4})-W(\d{2})$/.exec(week);
  if (!match) throw new RangeError(`Semaine invalide : ${week}`);
  const year = Number(match[1]);
  const weekNumber = Number(match[2]);
  if (weekNumber < 1 || weekNumber > weeksInIsoYear(year)) throw new RangeError(`Semaine invalide : ${week}`);
  // Le 4 janvier est toujours dans la semaine 1.
  const jan4 = `${year}-01-04`;
  const mondayWeek1 = addDaysIso(jan4, 1 - isoWeekday(jan4));
  return addDaysIso(mondayWeek1, (weekNumber - 1) * 7);
}

/** Semaine ISO d'une date. */
export function isoWeekOf(isoDate: string): string {
  const thursday = addDaysIso(isoDate, 4 - isoWeekday(isoDate));
  const year = Number(thursday.slice(0, 4));
  const mondayWeek1 = isoWeekMonday(`${year}-W01`);
  const week = Math.floor(daysBetween(mondayWeek1, thursday) / 7) + 1;
  return `${year}-W${String(week).padStart(2, '0')}`;
}

export function weekDays(week: string): string[] {
  const monday = isoWeekMonday(week);
  return Array.from({ length: 7 }, (_, i) => addDaysIso(monday, i));
}

export function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / DAY_MS);
}

function weeksInIsoYear(year: number): number {
  // 53 semaines si le 1er janvier ou le 31 décembre est un jeudi.
  const jan1 = isoWeekday(`${year}-01-01`);
  const dec31 = isoWeekday(`${year}-12-31`);
  return jan1 === 4 || dec31 === 4 ? 53 : 52;
}
