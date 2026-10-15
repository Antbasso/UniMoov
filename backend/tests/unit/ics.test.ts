import { describe, expect, it } from 'vitest';
import { daySlotsFromIntervals, InvalidCalendarError, parseIcsIntervals } from '../../src/modules/calendar/ics.js';

const wrap = (events: string, extra = '') =>
  ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//ADE//FR', extra, events, 'END:VCALENDAR'].filter(Boolean).join('\r\n');

const from = new Date('2026-10-12T00:00:00Z');
const to = new Date('2026-10-19T00:00:00Z');

describe('parseIcsIntervals', () => {
  it('lit des cours en UTC (export ADE) sans garder les titres', () => {
    const ics = wrap(
      [
        'BEGIN:VEVENT',
        'UID:1',
        'DTSTART:20261012T070000Z',
        'DTEND:20261012T090000Z',
        'SUMMARY:Algorithmique avancée',
        'LOCATION:Salle B204',
        'END:VEVENT',
      ].join('\r\n'),
    );
    const intervals = parseIcsIntervals(ics, from, to);
    expect(intervals).toEqual([{ start: new Date('2026-10-12T07:00:00Z'), end: new Date('2026-10-12T09:00:00Z') }]);
    expect(JSON.stringify(intervals)).not.toMatch(/Algorithmique|B204/);
  });

  it('heure flottante et TZID inconnu du fichier : heure de Paris', () => {
    const ics = wrap(
      [
        'BEGIN:VEVENT',
        'UID:2',
        'DTSTART:20261013T083000',
        'DTEND:20261013T100000',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:3',
        'DTSTART;TZID=Europe/Paris:20261014T140000',
        'DTEND;TZID=Europe/Paris:20261014T160000',
        'END:VEVENT',
      ].join('\r\n'),
    );
    const [floating, withTzid] = parseIcsIntervals(ics, from, to);
    expect(floating!.start.toISOString()).toBe('2026-10-13T06:30:00.000Z');
    expect(withTzid!.start.toISOString()).toBe('2026-10-14T12:00:00.000Z');
  });

  it('développe une récurrence hebdomadaire et respecte la fenêtre', () => {
    const ics = wrap(
      [
        'BEGIN:VEVENT',
        'UID:4',
        'DTSTART:20261005T070000Z',
        'DTEND:20261005T080000Z',
        'RRULE:FREQ=DAILY;COUNT=20',
        'END:VEVENT',
      ].join('\r\n'),
    );
    const days = parseIcsIntervals(ics, from, to).map((i) => i.start.toISOString().slice(0, 10));
    expect(days).toEqual(['2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16', '2026-10-17', '2026-10-18']);
  });

  it('ignore les journées entières et les événements annulés', () => {
    const ics = wrap(
      [
        'BEGIN:VEVENT',
        'UID:5',
        'DTSTART;VALUE=DATE:20261012',
        'DTEND;VALUE=DATE:20261013',
        'SUMMARY:Férié',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:6',
        'STATUS:CANCELLED',
        'DTSTART:20261012T070000Z',
        'DTEND:20261012T090000Z',
        'END:VEVENT',
      ].join('\r\n'),
    );
    expect(parseIcsIntervals(ics, from, to)).toEqual([]);
  });

  it('refuse un contenu qui n’est pas un agenda', () => {
    expect(() => parseIcsIntervals('<html>connexion requise</html>', from, to)).toThrow(InvalidCalendarError);
  });
});

describe('daySlotsFromIntervals', () => {
  it('garde le premier début et la dernière fin de chaque jour de Paris', () => {
    const slots = daySlotsFromIntervals([
      { start: new Date('2026-10-12T12:00:00Z'), end: new Date('2026-10-12T14:00:00Z') },
      { start: new Date('2026-10-12T07:00:00Z'), end: new Date('2026-10-12T09:00:00Z') },
      { start: new Date('2026-10-12T15:00:00Z'), end: new Date('2026-10-12T16:30:00Z') },
      // 23 h 30 UTC le 13 = 1 h 30 le 14 à Paris.
      { start: new Date('2026-10-13T23:30:00Z'), end: new Date('2026-10-14T00:30:00Z') },
    ]);
    expect(slots).toEqual([
      { day: '2026-10-12', start: new Date('2026-10-12T07:00:00Z'), end: new Date('2026-10-12T16:30:00Z') },
      { day: '2026-10-14', start: new Date('2026-10-13T23:30:00Z'), end: new Date('2026-10-14T00:30:00Z') },
    ]);
  });
});

describe('robustesse', () => {
  const victim = wrap(
    ['BEGIN:VEVENT', 'UID:v', 'DTSTART;TZID=Europe/Paris:20261013T080000', 'DTEND;TZID=Europe/Paris:20261013T090000', 'END:VEVENT'].join('\r\n'),
  );

  it('un fuseau déclaré par un agenda n’affecte pas la lecture des autres', () => {
    const before = parseIcsIntervals(victim, from, to)[0]!.start.toISOString();
    const evil = wrap(
      [
        'BEGIN:VEVENT',
        'UID:e',
        'DTSTART;TZID=Europe/Paris:20261012T080000',
        'DTEND;TZID=Europe/Paris:20261012T090000',
        'END:VEVENT',
      ].join('\r\n'),
      [
        'BEGIN:VTIMEZONE',
        'TZID:Europe/Paris',
        'BEGIN:STANDARD',
        'DTSTART:19700101T000000',
        'TZOFFSETFROM:+0500',
        'TZOFFSETTO:+0500',
        'END:STANDARD',
        'END:VTIMEZONE',
      ].join('\r\n'),
    );
    // Son propre fuseau s'applique à ses propres événements…
    expect(parseIcsIntervals(evil, from, to)[0]!.start.toISOString()).toBe('2026-10-12T03:00:00.000Z');
    // … mais pas à ceux des agendas lus ensuite.
    expect(parseIcsIntervals(victim, from, to)[0]!.start.toISOString()).toBe(before);
    expect(before).toBe('2026-10-13T06:00:00.000Z');
  });

  it('une récurrence quotidienne commencée il y a des années reste lue dans la fenêtre', () => {
    const old = wrap(
      ['BEGIN:VEVENT', 'UID:o', 'DTSTART:20000103T070000Z', 'DTEND:20000103T080000Z', 'RRULE:FREQ=DAILY', 'END:VEVENT'].join('\r\n'),
    );
    expect(parseIcsIntervals(old, from, to)).toHaveLength(7);
  });
});
