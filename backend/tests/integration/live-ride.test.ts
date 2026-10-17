import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type WebSocket from 'ws';
import { runSeed, SEED_PASSENGER_BALANCE_CENTS as SEED } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/**
 * Critères d'acceptation de M4 : position du conducteur en direct chez le passager, lien
 * Google Maps avec tous les arrêts dans l'ordre, présence validée = paiement équilibré au
 * registre, diffusion arrêtée à la clôture.
 */
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

async function call(firstName: string, method: 'GET' | 'POST', url: string, payload?: object, headers: Record<string, string> = {}) {
  return ctx.app.inject({
    method,
    url: `/api/v1${url}`,
    headers: { ...bearer(await login(firstName)), ...headers },
    ...(payload ? { payload } : {}),
  });
}

interface Live {
  ws: WebSocket;
  messages: Record<string, unknown>[];
  closed: Promise<number>;
}

async function connect(firstName: string | null, rideId: string, token?: string): Promise<Live> {
  const jwt = token ?? (firstName ? (await login(firstName)).accessToken : 'x');
  const ws = await ctx.app.injectWS(`/api/v1/ws/rides/${rideId}?token=${encodeURIComponent(jwt)}`);
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

/** Envoie une position ; l'horloge avance de 3 s (limite d'une position toutes les 2 s). */
async function sendPosition(live: Live, point: { lat: number; lon: number }) {
  ctx.clock.advance(3000);
  live.ws.send(JSON.stringify({ type: 'position', lat: point.lat, lon: point.lon, ts: ctx.clock.now.toISOString() }));
  await new Promise((r) => setTimeout(r, 60));
}

async function wallet(firstName: string) {
  const response = await call(firstName, 'GET', '/wallet');
  return response.json<{ balanceCents: number; heldCents: number; history: { kind: string; amountCents: number }[] }>();
}

let rideId: string;
let lea: Live;
let hugo: Live;

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
  // Lundi 7 h 30 à Paris : trente minutes avant l'arrivée prévue au campus.
  ctx.clock.now = new Date('2026-10-19T05:30:00Z');
});
afterAll(async () => {
  await ctx.close();
});

describe('portefeuille', () => {
  it('recharge idempotente (même clé, une seule écriture) et minimum configurable', async () => {
    const key = { 'idempotency-key': 'recharge-hugo-0001' };
    expect((await call('Hugo', 'POST', '/wallet/topups', { amountCents: 1000 }, key)).statusCode).toBe(201);
    expect((await call('Hugo', 'POST', '/wallet/topups', { amountCents: 1000 }, key)).statusCode).toBe(201);
    expect((await wallet('Hugo')).balanceCents).toBe(SEED + 1000);
    const small = await call('Hugo', 'POST', '/wallet/topups', { amountCents: 100 }, { 'idempotency-key': 'recharge-hugo-0002' });
    expect(small.json<{ error: { code: string } }>().error.code).toBe('topup_too_small');
    expect((await call('Hugo', 'POST', '/wallet/topups', { amountCents: 1000 })).statusCode).toBe(400);
    // Même clé, autre montant : refusé, rien de crédité.
    const conflict = await call('Hugo', 'POST', '/wallet/topups', { amountCents: 2000 }, key);
    expect(conflict.json<{ error: { code: string } }>().error.code).toBe('idempotency_conflict');
    expect((await wallet('Hugo')).balanceCents).toBe(SEED + 1000);
  });

  it('recharge refusée par le prestataire : rien n’est crédité', async () => {
    ctx.payments.failingAmounts.add(1300);
    const failed = await call('Inès', 'POST', '/wallet/topups', { amountCents: 1300 }, { 'idempotency-key': 'recharge-ines-0001' });
    expect(failed.statusCode).toBe(402);
    expect((await wallet('Inès')).balanceCents).toBe(SEED);
  });
});

describe('avant le départ', () => {
  it('le suivi est fermé : 4409 tant que le trajet n’a pas commencé, 4403 hors trajet, 4401 sans jeton valide', async () => {
    expect(await (await connect('Hugo', rideId)).closed).toBe(4409);
    expect(await (await connect('Nathan', rideId)).closed).toBe(4403);
    expect(await (await connect(null, rideId, 'pas-un-jeton')).closed).toBe(4401);
  });

  it('seul le conducteur démarre, et pas trop tôt', async () => {
    expect((await call('Hugo', 'POST', `/rides/${rideId}/start`)).statusCode).toBe(403);
    ctx.clock.now = new Date('2026-10-19T02:00:00Z');
    expect((await call('Léa', 'POST', `/rides/${rideId}/start`)).json<{ error: { code: string } }>().error.code).toBe('too_early');
    ctx.clock.now = new Date('2026-10-19T05:30:00Z');
  });
});

describe('trajet en cours', () => {
  it('au départ, le prix maximal (seul passager présent) est retenu sur le portefeuille du passager', async () => {
    expect((await call('Léa', 'POST', `/rides/${rideId}/start`)).statusCode).toBe(204);
    const view = (await call('Hugo', 'GET', `/rides/${rideId}`)).json<{ status: string; price: { youPayCents: number } }>();
    expect(view.status).toBe('in_progress');
    const w = await wallet('Hugo');
    // Plus que le prix estimé à plusieurs : le prix final, partagé entre les présents, ne le dépassera pas.
    expect(w.heldCents).toBeGreaterThan(view.price.youPayCents);
    expect(w.balanceCents).toBe(SEED + 1000 - w.heldCents);
  });

  it('une fois parti, on ne monte plus en route : accepter ou refuser est impossible', async () => {
    // Chloé était encore « proposée » sur ce trajet.
    const accept = await call('Chloé', 'POST', `/proposals/${rideId}/accept`);
    expect(accept.json<{ error: { code: string } }>().error.code).toBe('ride_unavailable');
    expect((await call('Chloé', 'POST', `/proposals/${rideId}/decline`)).statusCode).toBe(409);
    expect(await (await connect('Chloé', rideId)).closed).toBe(4403);
  });

  it('le passager voit la position du conducteur en direct, avec son heure de passage', async () => {
    lea = await connect('Léa', rideId);
    hugo = await connect('Hugo', rideId);
    expect(await waitFor(() => lea.messages.find((m) => m.type === 'ready'))).toMatchObject({ role: 'driver' });
    expect(await waitFor(() => hugo.messages.find((m) => m.type === 'ready'))).toMatchObject({ role: 'passenger' });
    await sendPosition(lea, { lat: 45.89, lon: 6.095 });
    const position = await waitFor(() => hugo.messages.find((m) => m.type === 'position'));
    expect(position).toMatchObject({ userId: user('Léa').id, lat: 45.89, lon: 6.095 });
    const eta = await waitFor(() => hugo.messages.find((m) => m.type === 'eta' && m.userId === user('Hugo').id));
    expect(new Date(eta.eta as string).getTime()).toBeGreaterThan(ctx.clock.now.getTime());
    // Les positions du passager vont au conducteur seulement.
    await sendPosition(hugo, { lat: 45.91, lon: 6.11 });
    await waitFor(() => lea.messages.find((m) => m.type === 'position' && m.userId === user('Hugo').id));
  });

  it('le lien Google Maps contient tous les arrêts restants dans l’ordre (conducteur seulement)', async () => {
    expect((await call('Hugo', 'GET', `/rides/${rideId}/navigation`)).statusCode).toBe(403);
    const nav = (await call('Léa', 'GET', `/rides/${rideId}/navigation`)).json<{
      stops: { firstName: string | null; lat: number; lon: number; kind: string }[];
      links: { googleMaps: string; waze: { nextStop: string } };
    }>();
    expect(nav.stops.map((s) => s.firstName)).toEqual(['Hugo', 'Inès', null]);
    const url = new URL(nav.links.googleMaps);
    const coord = (s: { lat: number; lon: number }) => `${s.lat.toFixed(6)},${s.lon.toFixed(6)}`;
    expect(url.searchParams.get('waypoints')).toBe(`${coord(nav.stops[0]!)}|${coord(nav.stops[1]!)}`);
    expect(url.searchParams.get('destination')).toBe(coord(nav.stops[2]!));
    expect(nav.links.waze.nextStop).toContain(coord(nav.stops[0]!));
    expect(nav.links.googleMaps).not.toMatch(/Hugo|Bernard|Cran/);
  });

  it('téléphones proches au ramassage : présence validée, rien n’est encore payé', async () => {
    const home = { lat: user('Hugo').lat, lon: user('Hugo').lon };
    // Le temps de rouler jusque chez Hugo : pas de saut invraisemblable.
    ctx.clock.advance(5 * 60_000);
    await sendPosition(lea, { lat: home.lat + 0.0005, lon: home.lon }); // ~55 m
    // Validée par le téléphone du passager, proche pendant au moins 15 s.
    await sendPosition(hugo, home);
    ctx.clock.advance(15_000);
    await sendPosition(lea, { lat: home.lat + 0.0005, lon: home.lon });
    await sendPosition(hugo, home);
    const validated = await waitFor(() => hugo.messages.find((m) => m.type === 'presence_validated'));
    expect(validated).toMatchObject({ userId: user('Hugo').id });
    // Paiement à l'arrivée seulement : la retenue est toujours là, Léa n'a rien reçu.
    expect((await wallet('Hugo')).heldCents).toBeGreaterThan(0);
    expect((await wallet('Léa')).balanceCents).toBe(0);
  });

  it('le registre est en écriture seule', async () => {
    await expect(ctx.database.pool.query(`UPDATE wallet_ledger SET amount_cents = 0`)).rejects.toThrow(/écriture seule/);
    await expect(ctx.database.pool.query(`DELETE FROM wallet_ledger`)).rejects.toThrow(/écriture seule/);
  });

  it('« monté » : signalé par le conducteur, l’arrêt sort de la navigation', async () => {
    expect((await call('Hugo', 'POST', `/rides/${rideId}/participants/${user('Hugo').id}/picked-up`)).statusCode).toBe(403);
    expect((await call('Léa', 'POST', `/rides/${rideId}/participants/${user('Hugo').id}/picked-up`)).statusCode).toBe(204);
    await waitFor(() => hugo.messages.find((m) => m.type === 'stop_picked_up'));
    const nav = (await call('Léa', 'GET', `/rides/${rideId}/navigation`)).json<{ links: { waze: { nextStop: string } } }>();
    expect(nav.links.waze.nextStop).toContain(user('Inès').lat.toFixed(6));
  });

  it('présence demandée trop loin du conducteur, ou avec des positions trop anciennes : refusée', async () => {
    const ines = await connect('Inès', rideId);
    await waitFor(() => ines.messages.find((m) => m.type === 'ready'));
    await sendPosition(ines, { lat: user('Inès').lat, lon: user('Inès').lon });
    const response = await call('Inès', 'POST', `/rides/${rideId}/presence`);
    expect(response.json<{ error: { code: string } }>().error.code).toBe('presence_not_confirmed');

    // Proches, mais la position du conducteur date de plus d'une minute.
    await sendPosition(ines, { lat: 45.89, lon: 6.095 });
    ctx.clock.advance(61_000);
    await sendPosition(ines, { lat: 45.89, lon: 6.095 });
    const stale = await call('Inès', 'POST', `/rides/${rideId}/presence`);
    expect(stale.json<{ error: { code: string } }>().error.code).toBe('presence_not_confirmed');
    ines.ws.terminate();
  });

  it('l’horodatage de la trace est celui du serveur, jamais celui envoyé par le client', async () => {
    lea.ws.send(JSON.stringify({ type: 'position', lat: 45.9, lon: 6.1, ts: '2099-01-01T00:00:00.000Z' }));
    ctx.clock.advance(31_000);
    lea.ws.send(JSON.stringify({ type: 'position', lat: 45.9, lon: 6.1, ts: '2099-01-01T00:00:00.000Z' }));
    await new Promise((r) => setTimeout(r, 100));
    const { rows } = await ctx.database.pool.query<{ latest: Date }>(`SELECT max(recorded_at) AS latest FROM position_trace`);
    expect(new Date(rows[0]!.latest).getTime()).toBeLessThanOrEqual(ctx.clock.now.getTime());
  });
});

describe('clôture', () => {
  it('arrivée au campus : Hugo arrivé paie le prix final, Inès laissée avant son heure n’est pas pénalisée', async () => {
    // Léa roule jusqu'au campus : Hugo, présent et à bord, arrive avec elle.
    ctx.clock.advance(10 * 60_000);
    await sendPosition(lea, { lat: 45.9195, lon: 6.158 });
    await waitFor(() => lea.messages.find((m) => m.type === 'passenger_arrived' && m.userId === user('Hugo').id));
    // Inès attend encore (jamais prise) : la conductrice clôt.
    expect((await call('Léa', 'POST', `/rides/${rideId}/finish`)).statusCode).toBe(204);
    expect(await lea.closed).toBe(4410);
    expect(await hugo.closed).toBe(4410);
    expect(hugo.messages.some((m) => m.type === 'ride_status' && m.status === 'completed')).toBe(true);
    expect(await (await connect('Hugo', rideId)).closed).toBe(4409);

    const { rows: statuses } = await ctx.database.pool.query<{ status: string; first_name: string }>(
      `SELECT p.status, u.first_name FROM ride_participants p JOIN users u ON u.id = p.user_id WHERE ride_id = $1 AND role = 'passenger'`,
      [rideId],
    );
    // Léa est passée au campus avant l'heure prévue chez Inès : pas une absence, Inès est prévenue.
    expect(Object.fromEntries(statuses.map((r) => [r.first_name, r.status]))).toMatchObject({ Hugo: 'picked_up', Inès: 'cancelled' });
    expect(ctx.notifier.sent).toContainEqual({ userIds: [user('Inès').id], event: { type: 'ride_cancelled', rideId, by: 'driver' } });

    // Prix final : coût ÷ personnes présentes (Hugo et Léa), payé par Hugo seul.
    const { rows: payments } = await ctx.database.pool.query<{ payer_id: string; status: string; share_cents: number; commission_cents: number }>(
      `SELECT payer_id, status, share_cents, commission_cents FROM payments WHERE ride_id = $1`,
      [rideId],
    );
    const hugoPayment = payments.find((p) => p.payer_id === user('Hugo').id)!;
    expect(hugoPayment.status).toBe('paid');
    const { rows: ride } = await ctx.database.pool.query<{ final_total_cost_cents: number }>(
      `SELECT final_total_cost_cents FROM rides WHERE id = $1`,
      [rideId],
    );
    expect(hugoPayment.share_cents).toBe(Math.ceil(ride[0]!.final_total_cost_cents / 2));
    const paid = hugoPayment.share_cents + hugoPayment.commission_cents;
    expect(await wallet('Hugo')).toMatchObject({ heldCents: 0, balanceCents: SEED + 1000 - paid });
    expect((await wallet('Léa')).balanceCents).toBe(hugoPayment.share_cents);
    expect(await wallet('Inès')).toMatchObject({ heldCents: 0, balanceCents: SEED });

    const { rows } = await ctx.database.pool.query<{ account: string; total: string }>(
      `SELECT account, sum(amount_cents) AS total FROM wallet_ledger WHERE ride_id = $1 GROUP BY account`,
      [rideId],
    );
    const byAccount = Object.fromEntries(rows.map((r) => [r.account, Number(r.total)]));
    expect(Object.values(byAccount).reduce((a, b) => a + b, 0)).toBe(0);
    expect(byAccount['platform:commission']).toBe(hugoPayment.commission_cents);
    expect(byAccount[`held:${user('Hugo').id}`]).toBe(0);
    // Clôture rejouée : sans effet.
    expect((await call('Léa', 'POST', `/rides/${rideId}/finish`)).statusCode).toBe(204);
  });

  it('trajet oublié « en cours » : clôturé automatiquement, départ refusé longtemps après', async () => {
    const tuesday = (await call('Léa', 'GET', '/proposals?week=2026-W43')).json<{ proposals: { id: string; day: string; direction: string }[] }>()
      .proposals.find((p) => p.day === '2026-10-20' && p.direction === 'to_campus')!.id;
    for (const name of ['Léa', 'Hugo']) await call(name, 'POST', `/proposals/${tuesday}/accept`);
    ctx.clock.now = new Date('2026-10-20T05:30:00Z');
    expect((await call('Léa', 'POST', `/rides/${tuesday}/start`)).statusCode).toBe(204);
    ctx.clock.now = new Date('2026-10-20T13:00:00Z');
    expect(await ctx.app.services!.lifecycle.closeStale()).toBe(1);
    expect((await call('Léa', 'GET', `/rides/${tuesday}`)).json<{ status: string }>().status).toBe('completed');

    const wednesday = (await call('Léa', 'GET', '/proposals?week=2026-W43')).json<{ proposals: { id: string; day: string; direction: string }[] }>()
      .proposals.find((p) => p.day === '2026-10-21' && p.direction === 'to_campus')!.id;
    for (const name of ['Léa', 'Hugo']) await call(name, 'POST', `/proposals/${wednesday}/accept`);
    ctx.clock.now = new Date('2026-10-21T14:00:00Z');
    expect((await call('Léa', 'POST', `/rides/${wednesday}/start`)).json<{ error: { code: string } }>().error.code).toBe('too_late');
  });

  it('passager qui termine avant l’arrivée : il ne paie pas, la conductrice est prévenue tout de suite', async () => {
    const thursday = (await call('Léa', 'GET', '/proposals?week=2026-W43')).json<{ proposals: { id: string; day: string; direction: string }[] }>()
      .proposals.find((p) => p.day === '2026-10-22' && p.direction === 'to_campus')!.id;
    for (const name of ['Léa', 'Hugo']) await call(name, 'POST', `/proposals/${thursday}/accept`);
    ctx.clock.now = new Date('2026-10-22T05:30:00Z');
    expect((await call('Léa', 'POST', `/rides/${thursday}/start`)).statusCode).toBe(204);
    expect(await ctx.app.services!.lifecycle.validatePresence(thursday, user('Hugo').id)).toBe('validated');
    const before = { hugo: (await wallet('Hugo')).balanceCents + (await wallet('Hugo')).heldCents, lea: (await wallet('Léa')).balanceCents };

    expect((await call('Hugo', 'POST', `/rides/${thursday}/finish`)).statusCode).toBe(204);
    expect(ctx.notifier.sent).toContainEqual({ userIds: [user('Léa').id], event: { type: 'passenger_left', rideId: thursday } });
    // Seul passager, il a fini : le trajet est clos ; il ne paie rien, Léa ne reçoit rien.
    expect((await call('Léa', 'GET', `/rides/${thursday}`)).json<{ status: string }>().status).toBe('completed');
    expect(await wallet('Hugo')).toMatchObject({ heldCents: 0, balanceCents: before.hugo });
    expect((await wallet('Léa')).balanceCents).toBe(before.lea);
  });

  it('trace réduite gardée pour les litiges, puis purgée après la rétention', async () => {
    const count = async () => Number((await ctx.database.pool.query<{ n: string }>(`SELECT count(*) AS n FROM position_trace`)).rows[0]!.n);
    expect(await count()).toBeGreaterThan(0);
    ctx.clock.advance(8 * 86_400_000);
    await ctx.app.services!.lifecycle.purgeTraces();
    expect(await count()).toBe(0);
  });
});
