import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type WebSocket from 'ws';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/**
 * Imitation de position (décision de l'équipe : contrôle de vraisemblance) : un conducteur qui
 * recopie la position reçue de son passager ne déclenche ni présence ni paiement.
 */
let ctx: TestContext;
const MONDAY = '2026-10-19';
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;
const tokens = new Map<string, Tokens>();

async function login(firstName: string): Promise<Tokens> {
  let t = tokens.get(firstName);
  if (!t) {
    const response = await ctx.app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { universityEmail: user(firstName).email, password: DEMO_PASSWORD },
    });
    t = response.json<Tokens>();
    tokens.set(firstName, t);
  }
  return t;
}
const call = async (firstName: string, method: 'GET' | 'POST', url: string, payload?: object) =>
  ctx.app.inject({ method, url: `/api/v1${url}`, headers: bearer(await login(firstName)), ...(payload ? { payload } : {}) });

async function connect(firstName: string, rideId: string) {
  const ws: WebSocket = await ctx.app.injectWS(`/api/v1/ws/rides/${rideId}?token=${encodeURIComponent((await login(firstName)).accessToken)}`);
  const messages: Record<string, unknown>[] = [];
  ws.on('message', (data: Buffer) => messages.push(JSON.parse(data.toString()) as Record<string, unknown>));
  const closed = new Promise<number>((resolve) => ws.on('close', (code: number) => resolve(code)));
  return { ws, messages, closed };
}

async function send(live: { ws: WebSocket }, point: { lat: number; lon: number }, advanceMs = 3000) {
  ctx.clock.advance(advanceMs);
  live.ws.send(JSON.stringify({ type: 'position', lat: point.lat, lon: point.lon, ts: ctx.clock.now.toISOString() }));
  await new Promise((r) => setTimeout(r, 60));
}

let rideId: string;

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
  await runSeed(ctx.database.db, { today: MONDAY });
  const list = await call('Léa', 'GET', '/proposals?week=2026-W43');
  rideId = list.json<{ proposals: { id: string; day: string; direction: string }[] }>().proposals.find(
    (p) => p.day === MONDAY && p.direction === 'to_campus',
  )!.id;
  for (const name of ['Léa', 'Hugo']) await call(name, 'POST', `/proposals/${rideId}/accept`);
  await ctx.app.inject({ method: 'POST', url: '/api/v1/wallet/topups', headers: { ...bearer(await login('Hugo')), 'idempotency-key': 'spoof-topup-0001' }, payload: { amountCents: 1000 } });
  ctx.clock.now = new Date('2026-10-19T05:30:00Z');
  expect((await call('Léa', 'POST', `/rides/${rideId}/start`)).statusCode).toBe(204);
});
afterAll(async () => {
  await ctx.close();
});

describe('conducteur qui recopie la position de son passager', () => {
  it('première position envoyée = adresse du passager, juste après le départ : pas crue', async () => {
    const lea = await connect('Léa', rideId);
    const hugo = await connect('Hugo', rideId);
    await new Promise((r) => setTimeout(r, 100));
    const home = { lat: user('Hugo').lat, lon: user('Hugo').lon };
    // Léa vient de démarrer de chez elle et n'a encore rien envoyé : elle « apparaît » chez Hugo.
    await send(lea, home, 1000);
    await send(hugo, home, 1000);
    await send(hugo, home, 16_000);
    expect(hugo.messages.some((m) => m.type === 'presence_validated')).toBe(false);
    lea.ws.terminate();
    hugo.ws.terminate();
    await new Promise((r) => setTimeout(r, 50));
  });

  it('saut impossible depuis 12 km : ni présence automatique, ni présence demandée, ni paiement', async () => {
    const lea = await connect('Léa', rideId);
    const hugo = await connect('Hugo', rideId);
    await new Promise((r) => setTimeout(r, 100));
    const home = { lat: user('Hugo').lat, lon: user('Hugo').lon };
    // Léa est loin (≈ 12 km), puis « apparaît » chez Hugo trois secondes plus tard.
    await send(lea, { lat: home.lat + 0.11, lon: home.lon });
    await send(hugo, home);
    await send(lea, home);
    // Hugo attend devant chez lui ; ses positions arrivent bien, plus de 15 s, mais Léa ne peut
    // pas avoir roulé jusque-là depuis son départ (≈ 2,5 km en une demi-minute).
    for (let i = 0; i < 2; i++) {
      await send(lea, home, 5000);
      await send(hugo, home, 1000);
    }
    expect(hugo.messages.some((m) => m.type === 'presence_validated')).toBe(false);
    const asked = await call('Hugo', 'POST', `/rides/${rideId}/presence`);
    expect(asked.json<{ error: { code: string } }>().error.code).toBe('presence_not_confirmed');
    const { rows } = await ctx.database.pool.query(`SELECT status FROM payments WHERE ride_id = $1 AND status = 'paid'`, [rideId]);
    expect(rows).toHaveLength(0);
  });

  it('la position du conducteur seule ne valide jamais un passager', async () => {
    // Le temps d'un vrai trajet depuis sa dernière position crue : Léa est de nouveau crue,
    // mais seul le téléphone du passager peut déclencher sa validation.
    ctx.clock.advance(11 * 60_000);
    const lea = await connect('Léa', rideId);
    const hugo = await connect('Hugo', rideId);
    await new Promise((r) => setTimeout(r, 100));
    const home = { lat: user('Hugo').lat, lon: user('Hugo').lon };
    await send(lea, home);
    await send(lea, home, 20_000);
    expect(hugo.messages.some((m) => m.type === 'presence_validated')).toBe(false);
    // Le passager est bien là : son téléphone, proche 15 s, valide.
    await send(hugo, home);
    await send(lea, home, 15_000);
    await send(hugo, home, 1000);
    await new Promise((r) => setTimeout(r, 100));
    expect(hugo.messages.some((m) => m.type === 'presence_validated')).toBe(true);
  });

  it('une seule connexion par personne : la nouvelle remplace l’ancienne (pas de diffusion multipliée)', async () => {
    const first = await connect('Hugo', rideId);
    await new Promise((r) => setTimeout(r, 50));
    await connect('Hugo', rideId);
    expect(await first.closed).toBe(4408);
  });
});
