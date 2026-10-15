import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bearer, setupTestContext, signUp, type TestContext, type Tokens } from './helpers.js';

let ctx: TestContext;
let lea: Tokens;
let hugo: Tokens;
const FEED = 'https://ade.univ-smb.fr/jsp/custom/modules/plannings/anonymous_cal.jsp?data=secret-token-lea';

const ics = (events: [string, string][]) =>
  [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    ...events.flatMap(([start, end], i) => [
      'BEGIN:VEVENT',
      `UID:${i}`,
      `DTSTART:${start}`,
      `DTEND:${end}`,
      'SUMMARY:Cours confidentiel',
      'DESCRIPTION:Groupe TD 2 - Mme Dupont',
      'END:VEVENT',
    ]),
    'END:VCALENDAR',
  ].join('\r\n');

const call = (tokens: Tokens, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
  ctx.app.inject({ method, url: `/api/v1${url}`, headers: bearer(tokens), ...(payload ? { payload } : {}) });

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  lea = await signUp(ctx, 'lea@etu.univ-smb.fr');
  ctx.clock.advance(61_000);
  hugo = await signUp(ctx, 'hugo@etu.univ-smb.fr');
  await call(lea, 'PUT', '/schedule/manual', { days: [{ weekday: 1, startTime: '09:00', endTime: '12:00' }] });
});
afterAll(async () => {
  await ctx.close();
});

describe('connexion d’un agenda ICS', () => {
  it('exige le consentement explicite', async () => {
    expect((await call(lea, 'POST', '/calendar/connections', { provider: 'ics', url: FEED })).statusCode).toBe(400);
    const refused = await call(lea, 'POST', '/calendar/connections', { provider: 'ics', url: FEED, consent: false });
    expect(refused.statusCode).toBe(400);
  });

  it('refuse un lien non HTTPS ou interne', async () => {
    for (const url of ['http://ade.univ-smb.fr/cal.ics', 'https://127.0.0.1/cal.ics', 'https://localhost/x.ics']) {
      const response = await call(lea, 'POST', '/calendar/connections', { provider: 'ics', url, consent: true });
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ error: { code: 'calendar_url_invalid' } });
    }
  });

  it('lien injoignable ou qui n’est pas un agenda : rien n’est enregistré', async () => {
    const missing = await call(lea, 'POST', '/calendar/connections', { provider: 'ics', url: FEED, consent: true });
    expect(missing.json()).toMatchObject({ error: { code: 'calendar_unreachable' } });
    ctx.icsFeeds.set(FEED, '<html>Connexion requise</html>');
    const invalid = await call(lea, 'POST', '/calendar/connections', { provider: 'ics', url: FEED, consent: true });
    expect(invalid.json()).toMatchObject({ error: { code: 'calendar_invalid' } });
    expect((await call(lea, 'GET', '/calendar/connections')).json()).toEqual({ connection: null });
  });

  it('connecte l’agenda : début et fin de journée seulement, lien chiffré et jamais renvoyé', async () => {
    ctx.icsFeeds.set(
      FEED,
      ics([
        ['20261019T060000Z', '20261019T080000Z'], // lundi 8 h - 10 h (heure de Paris)
        ['20261019T120000Z', '20261019T150000Z'], // lundi 14 h - 17 h
        ['20261021T070000Z', '20261021T100000Z'], // mercredi 9 h - 12 h
      ]),
    );
    const response = await call(lea, 'POST', '/calendar/connections', { provider: 'ics', url: FEED, consent: true });
    expect(response.statusCode).toBe(201);
    expect(JSON.stringify(response.json())).not.toContain('secret-token');

    const schedule = await call(lea, 'GET', '/schedule?from=2026-10-19&to=2026-10-26');
    expect(schedule.json()).toEqual({
      slots: [
        { day: '2026-10-19', start: '2026-10-19T06:00:00.000Z', end: '2026-10-19T15:00:00.000Z' },
        { day: '2026-10-21', start: '2026-10-21T07:00:00.000Z', end: '2026-10-21T10:00:00.000Z' },
      ],
    });

    const { rows } = await ctx.database.pool.query<{ encrypted_credentials: Buffer }>(
      'SELECT encrypted_credentials FROM calendar_connections',
    );
    expect(rows[0]!.encrypted_credentials.toString('latin1')).not.toContain('secret-token');
    const stored = await ctx.database.pool.query<{ t: string }>('SELECT row_to_json(s)::text AS t FROM schedule_slots s');
    expect(stored.rows.map((r) => r.t).join()).not.toMatch(/confidentiel|Dupont/);
  });

  it('une resynchronisation indique les jours modifiés', async () => {
    ctx.icsFeeds.set(
      FEED,
      ics([
        ['20261019T060000Z', '20261019T150000Z'],
        ['20261021T090000Z', '20261021T100000Z'], // mercredi décalé à 11 h
      ]),
    );
    const response = await call(lea, 'POST', '/calendar/sync');
    expect(response.statusCode).toBe(200);
    expect(response.json<{ changedDays: string[] }>().changedDays).toEqual(['2026-10-21']);
  });

  it('un autre utilisateur ne peut ni voir ni supprimer la connexion', async () => {
    const { connection } = (await call(lea, 'GET', '/calendar/connections')).json<{ connection: { id: string } }>();
    expect((await call(hugo, 'GET', '/calendar/connections')).json()).toEqual({ connection: null });
    expect((await call(hugo, 'DELETE', `/calendar/connections/${connection.id}`)).statusCode).toBe(404);
    expect((await call(hugo, 'POST', '/calendar/sync')).statusCode).toBe(404);
  });

  it('déconnexion : lien et créneaux supprimés, la semaine type reprend', async () => {
    const { connection } = (await call(lea, 'GET', '/calendar/connections')).json<{ connection: { id: string } }>();
    expect((await call(lea, 'DELETE', `/calendar/connections/${connection.id}`)).statusCode).toBe(204);
    const { rows } = await ctx.database.pool.query("SELECT 1 FROM schedule_slots WHERE source = 'calendar'");
    expect(rows).toHaveLength(0);
    const schedule = await call(lea, 'GET', '/schedule?from=2026-10-19&to=2026-10-20');
    expect(schedule.json()).toEqual({
      slots: [{ day: '2026-10-19', start: '2026-10-19T07:00:00.000Z', end: '2026-10-19T10:00:00.000Z' }],
    });
  });
});

describe('semaine type', () => {
  it('refuse une fin avant le début ou un jour en double', async () => {
    const reversed = await call(hugo, 'PUT', '/schedule/manual', {
      days: [{ weekday: 1, startTime: '18:00', endTime: '08:00' }],
    });
    expect(reversed.json()).toMatchObject({ error: { code: 'invalid_schedule' } });
    const duplicate = await call(hugo, 'PUT', '/schedule/manual', {
      days: [
        { weekday: 2, startTime: '08:00', endTime: '12:00' },
        { weekday: 2, startTime: '13:00', endTime: '17:00' },
      ],
    });
    expect(duplicate.json()).toMatchObject({ error: { code: 'duplicate_weekday' } });
    expect((await call(hugo, 'PUT', '/schedule/manual', { days: [{ weekday: 8, startTime: '08:00', endTime: '12:00' }] })).statusCode).toBe(400);
  });

  it('exige un JWT', async () => {
    expect((await ctx.app.inject({ method: 'GET', url: '/api/v1/schedule/manual' })).statusCode).toBe(401);
  });
});
