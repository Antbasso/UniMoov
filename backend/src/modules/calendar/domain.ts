import { addDaysIso, isoWeekday, parisToUtc } from '../../shared/time.js';
import type { DaySlot } from './ics.js';

/** Semaine type saisie à la main : jour ISO (1 = lundi) et heures de Paris `HH:MM`. */
export interface ManualDay {
  weekday: number;
  startTime: string;
  endTime: string;
}

/** Créneaux d'une semaine type sur `days` jours à partir de `fromDay` (fonction pure). */
export function manualSlots(template: readonly ManualDay[], fromDay: string, days: number): DaySlot[] {
  const byWeekday = new Map(template.map((d) => [d.weekday, d]));
  const slots: DaySlot[] = [];
  for (let i = 0; i < days; i++) {
    const day = addDaysIso(fromDay, i);
    const entry = byWeekday.get(isoWeekday(day));
    if (!entry) continue;
    slots.push({ day, start: parisToUtc(day, entry.startTime), end: parisToUtc(day, entry.endTime) });
  }
  return slots;
}

/** Jours dont le créneau effectif a changé (ajout, retrait ou nouvel horaire). */
export function changedDays(before: readonly DaySlot[], after: readonly DaySlot[]): string[] {
  const key = (s: DaySlot) => `${s.start.getTime()}-${s.end.getTime()}`;
  const old = new Map(before.map((s) => [s.day, key(s)]));
  const now = new Map(after.map((s) => [s.day, key(s)]));
  const days = new Set([...old.keys(), ...now.keys()]);
  return [...days].filter((d) => old.get(d) !== now.get(d)).sort();
}
