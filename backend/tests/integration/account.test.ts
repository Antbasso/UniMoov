import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/** RGPD : export de ses données, suppression du compte (docs/rgpd.md). */
let ctx: TestContext;
const MONDAY = '2026-10-19';
const tokens = new Map<string, Tokens>();
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;

async function login(firstName: string): Promise<Tokens> {
  const cached = tokens.get(firstName);
  if (cached) return cached;
  const response = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: { universityEmail: user(firstName).email, password: DEMO_PASSWORD },
  });
  const t = response.json<Tokens>();
  tokens.set(firstName, t);
  return t;
}

async function call(firstName: string, method: 'GET' | 'POST' | 'DELETE', url: string, payload?: object, headers: Record<string, string> = {}) {
  return ctx.app.inject({
    method,
    url: `/api/v1${url}`,
    headers: { ...bearer(await login(firstName)), ...headers },
    ...(payload ? { payload } : {}),
  });
}

const errorCode = (response: { json: <T>() => T }) => response.json<{ error: { code: string } }>().error.code;

let rideId: string;
let rideChatId: string;
let reportedMessageId: string;

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
  await runSeed(ctx.database.db, { today: MONDAY });
  const list = await call('Léa', 'GET', '/proposals?week=2026-W43');
  rideId = list.json<{ proposals: { id: string; day: string; direction: string }[] }>().proposals.find(
    (p) => p.day === MONDAY && p.direction === 'to_campus',
  )!.id;
  for (const name of ['Léa', 'Hugo', 'Inès']) {
    expect((await call(name, 'POST', `/proposals/${rideId}/accept`)).statusCode).toBe(200);
  }
  const chat = await call('Inès', 'GET', `/rides/${rideId}/conversation`);
  rideChatId = chat.json<{ id: string }>().id;
  expect((await call('Inès', 'POST', `/conversations/${rideChatId}/messages`, { body: 'Je serai devant la boulangerie.' })).statusCode).toBe(201);
  const reported = await call('Inès', 'POST', `/conversations/${rideChatId}/messages`, { body: 'Message insultant.' });
  reportedMessageId = reported.json<{ id: string }>().id;
});
afterAll(async () => {
  await ctx.close();
});

describe('GET /me/export', () => {
  it('exige une connexion', async () => {
    expect((await ctx.app.inject({ method: 'GET', url: '/api/v1/me/export' })).statusCode).toBe(401);
  });

  it('rassemble profil, trajets et préférences, sans aucun secret', async () => {
    const response = await call('Hugo', 'GET', '/me/export');
    expect(response.statusCode).toBe(200);
    expect(response.headers['content-disposition']).toContain('attachment');
    const data = response.json<{
      profile: { universityEmail: string; firstName: string };
      rides: { rideId: string; role: string; status: string }[];
      wallet: { balanceCents: number };
    }>();
    expect(data.profile).toMatchObject({ universityEmail: user('Hugo').email, firstName: 'Hugo' });
    expect(data.rides).toContainEqual(expect.objectContaining({ rideId, role: 'passenger', status: 'accepted' }));
    expect(data.wallet.balanceCents).toBe(0);
    expect(response.json<Record<string, unknown>>()).toHaveProperty('positionTrace');
    expect(response.body).not.toMatch(/password|argon2|token_hash|encrypted_credentials|push_token/i);
    // Rien des autres : ni leur nom de famille ni leur adresse.
    expect(response.body).not.toContain(user('Léa').lastName);
  });
});

describe('purge de nuit (minimisation)', () => {
  it('efface codes, sessions et créneaux périmés, garde ce qui sert encore', async () => {
    const q = (text: string, values: unknown[] = []) => ctx.database.pool.query(text, values);
    const now = ctx.clock.now;
    const ago = (days: number) => new Date(now.getTime() - days * 86_400_000);
    await q(`INSERT INTO verification_codes (email, code_hash, purpose, expires_at) VALUES
             ('ancien@etu.univ-smb.fr', 'h', 'signup', $1), ('recent@etu.univ-smb.fr', 'h', 'signup', $2)`, [ago(3), now]);
    await q(`INSERT INTO schedule_slots (user_id, day, start_at, end_at, source) VALUES ($1, $2, $3, $4, 'manual')`, [
      user('Hugo').id,
      ago(10).toISOString().slice(0, 10),
      ago(10),
      ago(10),
    ]);
    // Jeton déjà échangé mais pas expiré : gardé, sa réutilisation doit encore révéler un vol.
    await q(`INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at, used_at)
             VALUES ($1, gen_random_uuid(), 'deja-utilise', $2, $3)`, [user('Hugo').id, new Date(now.getTime() + 86_400_000), ago(5)]);
    const purged = await ctx.app.services!.account.purgeExpired();
    expect((await q(`SELECT 1 FROM refresh_tokens WHERE token_hash = 'deja-utilise'`)).rows).toHaveLength(1);
    expect(purged.verificationCodes).toBe(1);
    expect(purged.scheduleSlots).toBe(1);
    const { rows } = await q(`SELECT email FROM verification_codes WHERE email LIKE '%etu.univ-smb.fr' AND code_hash = 'h'`);
    expect(rows).toEqual([{ email: 'recent@etu.univ-smb.fr' }]);
    // Les sessions en cours restent valides.
    expect((await call('Hugo', 'GET', '/me')).statusCode).toBe(200);
  });
});

describe('DELETE /me', () => {
  it('mauvais mot de passe : refusé, compte intact', async () => {
    const response = await call('Inès', 'DELETE', '/me', { password: 'pas-le-bon' });
    expect(response.statusCode).toBe(401);
    expect(errorCode(response)).toBe('invalid_password');
    expect((await call('Inès', 'GET', '/me')).statusCode).toBe(200);
  });

  it('portefeuille non vide : refusé tant que le solde n’est pas récupéré', async () => {
    await call('Hugo', 'POST', '/wallet/topups', { amountCents: 1000 }, { 'idempotency-key': 'recharge-hugo-rgpd-1' });
    const response = await call('Hugo', 'DELETE', '/me', { password: DEMO_PASSWORD });
    expect(response.statusCode).toBe(409);
    expect(errorCode(response)).toBe('wallet_not_empty');
  });

  it('supprime et anonymise ; les autres sont prévenus, le trajet continue sans elle', async () => {
    const ines = user('Inès');
    await ctx.database.pool.query(
      `INSERT INTO reports (reporter_id, target_user_id, target_message_id, reason) VALUES ($1, $2, $3, 'inappropriate_behaviour')`,
      [user('Hugo').id, ines.id, reportedMessageId],
    );
    const response = await call('Inès', 'DELETE', '/me', { password: DEMO_PASSWORD });
    expect(response.statusCode).toBe(204);

    // Plus de session, plus de connexion.
    expect((await call('Inès', 'GET', '/me')).statusCode).toBe(401);
    const relogin = await ctx.app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { universityEmail: ines.email, password: DEMO_PASSWORD },
    });
    expect(relogin.statusCode).toBe(401);

    // Sa place est libérée comme pour une annulation ; Léa et Hugo restent.
    expect(ctx.notifier.sent).toContainEqual(
      expect.objectContaining({ event: { type: 'ride_cancelled', rideId, by: 'passenger' } }),
    );
    const ride = await call('Léa', 'GET', `/rides/${rideId}`);
    expect(ride.body).not.toContain('Inès');
    // Ses messages disparaissent aussi du chat du trajet.
    const messages = await call('Hugo', 'GET', `/conversations/${rideChatId}/messages`);
    expect(messages.statusCode).toBe(200);
    expect(messages.body).not.toContain('boulangerie');

    // Données personnelles effacées ; l'historique pseudonyme reste.
    const { rows } = await ctx.database.pool.query<Record<string, unknown>>(
      `SELECT university_email, first_name, last_name, password_hash, home_address, home_location, deleted_at
       FROM users WHERE id = $1`,
      [ines.id],
    );
    expect(rows[0]).toMatchObject({ first_name: 'Ancien membre', last_name: '', password_hash: null, home_address: null, home_location: null });
    expect(rows[0]!.university_email).not.toBe(ines.email);
    expect(rows[0]!.deleted_at).not.toBeNull();
    for (const table of ['vehicles', 'schedule_slots', 'manual_schedule_days', 'refresh_tokens', 'conversation_members']) {
      const { rows: left } = await ctx.database.pool.query(`SELECT 1 FROM ${table} WHERE user_id = $1`, [ines.id]);
      expect(left, table).toHaveLength(0);
    }
    // Seul le message signalé reste, comme preuve pour l'équipe.
    const { rows: kept } = await ctx.database.pool.query(`SELECT id FROM messages WHERE sender_id = $1`, [ines.id]);
    expect(kept).toEqual([{ id: reportedMessageId }]);
    const { rows: history } = await ctx.database.pool.query(
      `SELECT status, pickup_label FROM ride_participants WHERE ride_id = $1 AND user_id = $2`,
      [rideId, ines.id],
    );
    expect(history[0]).toMatchObject({ status: 'cancelled', pickup_label: null });

    // L'adresse universitaire est libre : une nouvelle inscription reçoit un vrai code.
    const again = await ctx.app.inject({
      method: 'POST',
      url: '/api/v1/auth/signup/request-code',
      payload: { universityEmail: ines.email },
    });
    expect(again.statusCode).toBe(202);
    expect(ctx.mail.lastTo(ines.email)?.subject).toMatch(/\d{6}/);
  });

  it('trajet en cours : refusé jusqu’à la clôture', async () => {
    ctx.clock.now = new Date('2026-10-19T05:30:00Z');
    expect((await call('Léa', 'POST', `/rides/${rideId}/start`)).statusCode).toBe(204);
    const response = await call('Léa', 'DELETE', '/me', { password: DEMO_PASSWORD });
    expect(response.statusCode).toBe(409);
    expect(errorCode(response)).toBe('ride_in_progress');
  });
});
