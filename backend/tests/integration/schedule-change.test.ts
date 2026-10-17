import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/** Horaire du conducteur modifié alors qu'un passager avait déjà accepté : prévenu, pas effacé. */
let ctx: TestContext;
const MONDAY = '2026-10-19';
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;
const tokens = new Map<string, Tokens>();

async function call(firstName: string, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) {
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

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
  await runSeed(ctx.database.db, { today: MONDAY });
});
afterAll(async () => {
  await ctx.close();
});

describe('horaire du conducteur modifié', () => {
  it('trajet déjà accepté par un passager : annulé et passager prévenu', async () => {
    const list = await call('Hugo', 'GET', '/proposals?week=2026-W43');
    const monday = list.json<{ proposals: { id: string; day: string; direction: string; driver: { firstName: string } | null }[] }>()
      .proposals.find((p) => p.day === MONDAY && p.direction === 'to_campus' && p.driver?.firstName === 'Léa')!;
    expect((await call('Hugo', 'POST', `/proposals/${monday.id}/accept`)).statusCode).toBe(200);

    const manual = (await call('Léa', 'GET', '/schedule/manual')).json<{ days: { weekday: number }[] }>();
    const response = await call('Léa', 'PUT', '/schedule/manual', { days: manual.days.filter((d) => d.weekday !== 1) });
    expect(response.statusCode).toBe(200);

    expect(ctx.notifier.sent).toContainEqual({
      userIds: [user('Hugo').id],
      event: { type: 'ride_cancelled', rideId: monday.id, by: 'driver' },
    });
    const { rows } = await ctx.database.pool.query<{ status: string }>(`SELECT status FROM rides WHERE id = $1`, [monday.id]);
    expect(rows[0]?.status).toBe('cancelled');
  });
});
