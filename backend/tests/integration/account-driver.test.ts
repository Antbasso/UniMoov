import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/** Suppression du compte d'une conductrice : ses trajets sont libérés sans la reprendre. */
let ctx: TestContext;
const MONDAY = '2026-10-19';
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;
const tokens = new Map<string, Tokens>();

async function call(firstName: string, method: 'GET' | 'POST' | 'DELETE', url: string, payload?: object) {
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
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: bearer(t), ...(payload ? { payload } : {}) });
}

const activeRides = async (driverId: string) =>
  (
    await ctx.database.pool.query<{ id: string }>(
      `SELECT id FROM rides WHERE driver_id = $1 AND status IN ('proposed', 'confirmed')`,
      [driverId],
    )
  ).rows;

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
  await runSeed(ctx.database.db, { today: MONDAY });
  const list = await call('Léa', 'GET', '/proposals?week=2026-W43');
  const monday = list.json<{ proposals: { id: string; day: string; direction: string }[] }>().proposals.find(
    (p) => p.day === MONDAY && p.direction === 'to_campus',
  )!.id;
  for (const name of ['Léa', 'Hugo']) await call(name, 'POST', `/proposals/${monday}/accept`);
});
afterAll(async () => {
  await ctx.close();
});

describe('suppression d’une conductrice', () => {
  it('aucun trajet ne la reprend, ses passagers sont prévenus et retrouvent des propositions', async () => {
    const lea = user('Léa');
    expect((await activeRides(lea.id)).length).toBeGreaterThan(0);
    const nathanBefore = (await activeRides(user('Nathan').id)).length;

    expect((await call('Léa', 'DELETE', '/me', { password: DEMO_PASSWORD })).statusCode).toBe(204);

    // Ni trajet ouvert à son nom, ni nouveau trajet créé par la régénération.
    expect(await activeRides(lea.id)).toHaveLength(0);
    expect(ctx.notifier.sent).toContainEqual(
      expect.objectContaining({ userIds: [user('Hugo').id], event: { type: 'ride_cancelled', rideId: expect.any(String) as string, by: 'driver' } }),
    );
    // Les trajets des autres conducteurs ne sont pas effacés au passage.
    expect((await activeRides(user('Nathan').id)).length).toBeGreaterThanOrEqual(nathanBefore);
    // Hugo n'est pas laissé sans rien : ses propositions de la semaine restent lisibles.
    const hugo = await call('Hugo', 'GET', '/proposals?week=2026-W43');
    expect(hugo.statusCode).toBe(200);
    const proposals = hugo.json<{
      proposals: { day: string; rideStatus: string; driver: { firstName: string } | null }[];
    }>().proposals;
    // Une autre voiture lui est proposée lundi ; l'ancienne ne montre plus que « Ancien membre ».
    expect(proposals.some((p) => p.day === MONDAY && p.rideStatus === 'proposed' && p.driver?.firstName !== 'Ancien membre')).toBe(true);
    expect(hugo.body).not.toContain('Léa');
  });
});
