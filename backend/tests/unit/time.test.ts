import { describe, expect, it } from 'vitest';
import {
  addDaysIso,
  isoWeekday,
  isoWeekMonday,
  isoWeekOf,
  parisDateOf,
  parisOffsetMinutes,
  parisTimeOf,
  parisToUtc,
  weekDays,
} from '../../src/shared/time.js';

describe('fuseau de Paris', () => {
  it('décalage hiver +60, été +120', () => {
    expect(parisOffsetMinutes(new Date('2026-01-15T12:00:00Z'))).toBe(60);
    expect(parisOffsetMinutes(new Date('2026-07-15T12:00:00Z'))).toBe(120);
  });

  it('heure murale → UTC, de part et d’autre du changement d’heure', () => {
    expect(parisToUtc('2026-01-15', '08:00').toISOString()).toBe('2026-01-15T07:00:00.000Z');
    expect(parisToUtc('2026-07-15', '08:00').toISOString()).toBe('2026-07-15T06:00:00.000Z');
    // Passage à l'heure d'été : 29 mars 2026 à 2 h.
    expect(parisToUtc('2026-03-29', '08:00').toISOString()).toBe('2026-03-29T06:00:00.000Z');
    expect(parisToUtc('2026-03-28', '08:00').toISOString()).toBe('2026-03-28T07:00:00.000Z');
    // Retour à l'heure d'hiver : 25 octobre 2026.
    expect(parisToUtc('2026-10-25', '18:30').toISOString()).toBe('2026-10-25T17:30:00.000Z');
  });

  it('date et heure de Paris d’un instant', () => {
    expect(parisDateOf(new Date('2026-10-15T22:30:00Z'))).toBe('2026-10-16');
    expect(parisTimeOf(new Date('2026-10-15T06:15:00Z'))).toBe('08:15');
  });
});

describe('semaines ISO', () => {
  it('lundi de la semaine', () => {
    expect(isoWeekMonday('2026-W42')).toBe('2026-10-12');
    expect(isoWeekMonday('2026-W01')).toBe('2025-12-29');
    expect(isoWeekMonday('2026-W53')).toBe('2026-12-28'); // 2026 a 53 semaines
  });

  it('semaine d’une date, y compris en fin et début d’année', () => {
    expect(isoWeekOf('2026-10-15')).toBe('2026-W42');
    expect(isoWeekOf('2027-01-01')).toBe('2026-W53');
    expect(isoWeekOf('2025-12-29')).toBe('2026-W01');
  });

  it('refuse une semaine invalide', () => {
    expect(() => isoWeekMonday('2025-W53')).toThrow(RangeError);
    expect(() => isoWeekMonday('2026-42')).toThrow(RangeError);
    expect(() => isoWeekMonday('2026-W00')).toThrow(RangeError);
  });

  it('jours de la semaine et jour ISO', () => {
    expect(weekDays('2026-W42')).toEqual([
      '2026-10-12',
      '2026-10-13',
      '2026-10-14',
      '2026-10-15',
      '2026-10-16',
      '2026-10-17',
      '2026-10-18',
    ]);
    expect(isoWeekday('2026-10-12')).toBe(1);
    expect(isoWeekday('2026-10-18')).toBe(7);
    expect(addDaysIso('2026-12-31', 1)).toBe('2027-01-01');
  });
});
