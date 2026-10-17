import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type WebSocket from 'ws';
import { FAKE_ADDRESSES } from '../../src/shared/geocoding/fake-geocoding-provider.js';
import { bearer, setupTestContext, signUp, type TestContext, type Tokens } from './helpers.js';

/**
 * Critère d'acceptation de M7 : deux étudiants qui ne se connaissent pas, sur une base vide,
 * de l'inscription à la note — inscription, profil, emploi du temps, proposition acceptée des
 * deux côtés, départ, présence validée par la proximité, paiement, clôture, notes croisées.
 */
let ctx: TestContext;
let camille: Tokens;
let yanis: Tokens;
const ids: Record<string, string> = {};

const call = (who: Tokens, method: 'GET' | 'POST' | 'PUT' | 'PATCH', url: string, payload?: object, headers: Record<string, string> = {}) =>
  ctx.app.inject({ method, url: `/api/v1${url}`, headers: { ...bearer(who), ...headers }, ...(payload ? { payload } : {}) });

async function connect(who: Tokens, rideId: string) {
  const ws: WebSocket = await ctx.app.injectWS(`/api/v1/ws/rides/${rideId}?token=${encodeURIComponent(who.accessToken)}`);
  const messages: Record<string, unknown>[] = [];
  ws.on('message', (data: Buffer) => messages.push(JSON.parse(data.toString()) as Record<string, unknown>));
  const closed = new Promise<number>((resolve) => ws.on('close', (code: number) => resolve(code)));
  return { ws, messages, closed };
}

async function waitFor<T>(fn: () => T | undefined, timeoutMs = 3000): Promise<T> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const value = fn();
    if (value !== undefined) return value;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error('délai dépassé');
}

async function sendPosition(live: { ws: WebSocket }, point: { lat: number; lon: number }) {
  ctx.clock.advance(3000);
  live.ws.send(JSON.stringify({ type: 'position', lat: point.lat, lon: point.lon, ts: ctx.clock.now.toISOString() }));
  await new Promise((r) => setTimeout(r, 60));
}

beforeAll(async () => {
  // Dimanche : la semaine suivante (W43) est encore à générer.
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
});
afterAll(async () => {
  await ctx.close();
});

describe('parcours complet', () => {
  it('inscription : compte créé, mode découverte tant que le domicile manque', async () => {
    camille = await signUp(ctx, 'camille.durand@etu.univ-smb.fr', { firstName: 'Camille', lastName: 'Durand' });
    ctx.clock.advance(61_000);
    yanis = await signUp(ctx, 'yanis.benali@etu.univ-smb.fr', { firstName: 'Yanis', lastName: 'Benali' });
    const me = (await call(yanis, 'GET', '/me')).json<{ id: string; discoveryMode: boolean }>();
    expect(me.discoveryMode).toBe(true);
    ids.yanis = me.id;
    ids.camille = (await call(camille, 'GET', '/me')).json<{ id: string }>().id;
  });

  it('profil et emploi du temps : la conductrice et le passager sont prêts', async () => {
    expect((await call(camille, 'PUT', '/me/address', { address: '12 rue de la Paix Annecy' })).statusCode).toBe(200);
    expect((await call(camille, 'PUT', '/me/vehicle', { consumptionLPer100km: 6, defaultSeats: 3, maxDetourMinutes: 15 })).statusCode).toBe(200);
    expect((await call(camille, 'PATCH', '/me/preferences', { roleMode: 'always_driver', defaultNavApp: 'google_maps' })).statusCode).toBe(200);
    const yanisHome = await call(yanis, 'PUT', '/me/address', { address: '1 place de l’Hôtel de Ville Seynod' });
    expect(yanisHome.json<{ discoveryMode: boolean }>().discoveryMode).toBe(false);
    for (const who of [camille, yanis]) {
      const schedule = await call(who, 'PUT', '/schedule/manual', { days: [{ weekday: 1, startTime: '08:00', endTime: '17:00' }] });
      expect(schedule.statusCode).toBe(200);
    }
  });

  it('proposition : le même trajet chez les deux, sans nom de famille ni adresse avant accord', async () => {
    const list = await call(yanis, 'GET', '/proposals?week=2026-W43');
    const proposals = list.json<{ proposals: { id: string; day: string; direction: string }[] }>().proposals;
    const monday = proposals.find((p) => p.day === '2026-10-19' && p.direction === 'to_campus');
    expect(monday).toBeDefined();
    ids.ride = monday!.id;
    expect(list.body).not.toMatch(/Durand|Rue de la Paix/);

    expect((await call(yanis, 'POST', `/proposals/${ids.ride}/accept`)).statusCode).toBe(200);
    const accepted = await call(camille, 'POST', `/proposals/${ids.ride}/accept`);
    expect(accepted.json<{ rideStatus: string }>().rideStatus).toBe('confirmed');
    // Le chat du trajet s'ouvre à la confirmation.
    expect((await call(yanis, 'GET', `/rides/${ids.ride}/conversation`)).statusCode).toBe(200);
  });

  it('trajet : départ, présence validée par la proximité, paiement depuis le portefeuille', async () => {
    expect((await call(yanis, 'POST', '/wallet/topups', { amountCents: 1000 }, { 'idempotency-key': 'yanis-recharge-01' })).statusCode).toBe(201);
    ctx.clock.now = new Date('2026-10-19T05:30:00Z');
    expect((await call(camille, 'POST', `/rides/${ids.ride}/start`)).statusCode).toBe(204);

    const driver = await connect(camille, ids.ride!);
    const passenger = await connect(yanis, ids.ride!);
    await waitFor(() => driver.messages.find((m) => m.type === 'ready'));
    await waitFor(() => passenger.messages.find((m) => m.type === 'ready'));
    const home = FAKE_ADDRESSES['1 place de l hotel de ville seynod']!;
    await sendPosition(passenger, home);
    await sendPosition(driver, { lat: home.lat + 0.0004, lon: home.lon });
    expect(await waitFor(() => passenger.messages.find((m) => m.type === 'presence_validated'))).toMatchObject({
      userId: ids.yanis,
      payment: 'paid',
    });
    expect((await call(camille, 'POST', `/rides/${ids.ride}/participants/${ids.yanis}/picked-up`)).statusCode).toBe(204);

    // Clôture : le suivi s'arrête pour les deux.
    expect((await call(camille, 'POST', `/rides/${ids.ride}/finish`)).statusCode).toBe(204);
    expect(await driver.closed).toBe(4410);
    expect(await passenger.closed).toBe(4410);

    const yanisWallet = (await call(yanis, 'GET', '/wallet')).json<{ balanceCents: number; heldCents: number }>();
    const camilleWallet = (await call(camille, 'GET', '/wallet')).json<{ balanceCents: number }>();
    expect(yanisWallet.heldCents).toBe(0);
    expect(yanisWallet.balanceCents).toBeLessThan(1000);
    expect(camilleWallet.balanceCents).toBeGreaterThan(0);
    const { rows } = await ctx.database.pool.query<{ total: string }>(
      `SELECT sum(amount_cents) AS total FROM wallet_ledger WHERE ride_id = $1`,
      [ids.ride],
    );
    expect(Number(rows[0]!.total)).toBe(0);
  });

  it('note : chacun note l’autre une fois, la fiabilité en tient compte', async () => {
    const view = (await call(yanis, 'GET', `/rides/${ids.ride}`)).json<{ status: string }>();
    expect(view.status).toBe('completed');
    const ratings = (await call(yanis, 'GET', `/rides/${ids.ride}/ratings`)).json<{ open: boolean; people: { userId: string }[] }>();
    expect(ratings.open).toBe(true);
    expect(ratings.people.map((p) => p.userId)).toEqual([ids.camille]);

    expect((await call(yanis, 'POST', `/rides/${ids.ride}/ratings`, { ratedUserId: ids.camille, stars: 5 })).statusCode).toBe(204);
    expect((await call(camille, 'POST', `/rides/${ids.ride}/ratings`, { ratedUserId: ids.yanis, stars: 4 })).statusCode).toBe(204);
    const again = await call(yanis, 'POST', `/rides/${ids.ride}/ratings`, { ratedUserId: ids.camille, stars: 1 });
    expect(again.statusCode).toBe(409);

    const reliability = (await call(camille, 'GET', '/me/reliability')).json<{ completedRides: number; ratingsCount: number }>();
    expect(reliability).toMatchObject({ completedRides: 1, ratingsCount: 1 });
  });
});
