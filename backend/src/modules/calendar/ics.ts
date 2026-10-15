import ICAL from 'ical.js';
import { parisDateOf, parisToUtc } from '../../shared/time.js';

/**
 * Lecture d'un agenda ICS : on n'en garde que des intervalles horaires (début, fin).
 * Titres, descriptions, lieux et participants ne sont jamais conservés (AGENTS.md, RGPD).
 */
export interface Interval {
  start: Date;
  end: Date;
}

export class InvalidCalendarError extends Error {
  override readonly name = 'InvalidCalendarError';
}

/** Occurrences gardées dans la fenêtre, et itérations au total (récurrences anciennes). */
const MAX_OCCURRENCES = 5000;
const MAX_ITERATIONS = 200_000;

function toUtc(time: ICAL.Time): Date {
  // Heure « flottante » ou fuseau inconnu du fichier : heure de Paris (campus du pilote).
  const tzid = time.zone?.tzid;
  if (!tzid || tzid === 'floating' || (tzid !== 'UTC' && !ICAL.TimezoneService.has(tzid))) {
    const pad = (n: number) => String(n).padStart(2, '0');
    return parisToUtc(`${time.year}-${pad(time.month)}-${pad(time.day)}`, `${pad(time.hour)}:${pad(time.minute)}`);
  }
  return time.toJSDate();
}

/** Intervalles des événements (récurrences développées) qui touchent [from, to[. */
export function parseIcsIntervals(text: string, from: Date, to: Date): Interval[] {
  let root: ICAL.Component;
  try {
    root = new ICAL.Component(ICAL.parse(text) as unknown[]);
  } catch {
    throw new InvalidCalendarError('Fichier ICS illisible');
  }
  if (root.name !== 'vcalendar') throw new InvalidCalendarError('Ce lien ne renvoie pas un agenda');

  // Le registre des fuseaux d'ical.js est global au processus : les fuseaux d'un agenda n'y
  // restent que le temps de sa lecture (synchrone), sinon un fichier malveillant fausserait
  // la lecture des agendas des autres utilisateurs.
  const registered: string[] = [];
  try {
    for (const vtimezone of root.getAllSubcomponents('vtimezone')) {
      const timezone = new ICAL.Timezone(vtimezone);
      if (timezone.tzid && !ICAL.TimezoneService.has(timezone.tzid)) {
        ICAL.TimezoneService.register(timezone, timezone.tzid);
        registered.push(timezone.tzid);
      }
    }
    return collectIntervals(root, from, to);
  } finally {
    for (const tzid of registered) ICAL.TimezoneService.remove(tzid);
  }
}

function collectIntervals(root: ICAL.Component, from: Date, to: Date): Interval[] {
  const intervals: Interval[] = [];
  let iterations = 0;
  const push = (startTime: ICAL.Time, endTime: ICAL.Time | null) => {
    if (startTime.isDate) return; // journée entière (vacances, fériés) : pas un cours
    const start = toUtc(startTime);
    const end = endTime ? toUtc(endTime) : start;
    if (end > from && start < to && end >= start) intervals.push({ start, end });
  };

  for (const vevent of root.getAllSubcomponents('vevent')) {
    if (intervals.length >= MAX_OCCURRENCES) break;
    const status = vevent.getFirstPropertyValue('status');
    if (typeof status === 'string' && status.toUpperCase() === 'CANCELLED') continue;
    const event = new ICAL.Event(vevent);
    if (!event.startDate) continue;

    if (!event.isRecurring()) {
      push(event.startDate, event.endDate);
      continue;
    }
    const iterator = event.iterator();
    for (let next = iterator.next(); next; next = iterator.next()) {
      // Seules les occurrences de la fenêtre comptent ; une récurrence ancienne est parcourue
      // jusqu'à la fenêtre, dans la limite d'un nombre d'itérations.
      if (++iterations > MAX_ITERATIONS || intervals.length >= MAX_OCCURRENCES) break;
      const details = event.getOccurrenceDetails(next) as { startDate: ICAL.Time; endDate: ICAL.Time };
      if (toUtc(details.startDate) >= to) break;
      push(details.startDate, details.endDate);
    }
  }
  return intervals;
}

export interface DaySlot {
  day: string; // AAAA-MM-JJ (Paris)
  start: Date;
  end: Date;
}

/** Début de la première activité et fin de la dernière, par jour de Paris. */
export function daySlotsFromIntervals(intervals: readonly Interval[]): DaySlot[] {
  const byDay = new Map<string, DaySlot>();
  for (const { start, end } of intervals) {
    const day = parisDateOf(start);
    const current = byDay.get(day);
    byDay.set(day, {
      day,
      start: current && current.start < start ? current.start : start,
      end: current && current.end > end ? current.end : end,
    });
  }
  return [...byDay.values()].sort((a, b) => a.day.localeCompare(b.day));
}
