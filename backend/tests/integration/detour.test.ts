import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { distanceMeters, type LatLon } from '../../src/shared/geo.js';
import type { RouteResult, RoutingProvider } from '../../src/shared/routing/routing-provider.js';
import { bearer, setupTestContext, type TestContext } from './helpers.js';

/** Itinéraires « réels » de test : ligne droite à 10 m/s (un vrai fournisseur, pas l'estimation). */
const roads: RoutingProvider = {
  route(points: readonly LatLon[]): Promise<RouteResult> {
    const legs = points.slice(1).map((p, i) => {
      const distanceM = Math.round(distanceMeters(points[i]!, p));
      return { distanceM, durationS: Math.round(distanceM / 10) };
    });
    return Promise.resolve({
      distanceM: legs.reduce((a, l) => a + l.distanceM, 0),
      durationS: legs.reduce((a, l) => a + l.durationS, 0),
      legs,
      geometry: [...points],
      estimated: false,
    });
  },
};

let ctx: TestContext;
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;
const call = async (firstName: string, method: 'GET' | 'POST', url: string) => {
  const login = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: { universityEmail: user(firstName).email, password: DEMO_PASSWORD },
  });
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: bearer(login.json()) });
};

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'), { routing: roads });
  await runSeed(ctx.database.db, { today: '2026-10-19' });
});
afterAll(async () => {
  await ctx.close();
});

describe('détour (cahier §4)', () => {
  it('une fois le trajet planifié, le détour affiché est celui des vrais itinéraires', async () => {
    type P = { id: string; day: string; direction: string; detourMinutes: number; driver: { detourMinutes: number } | null };
    const find = async (name: string) =>
      (await call(name, 'GET', '/proposals?week=2026-W43')).json<{ proposals: P[] }>().proposals.find(
        (p) => p.day === '2026-10-19' && p.direction === 'to_campus',
      )!;
    const rideId = (await find('Léa')).id;
    for (const name of ['Léa', 'Hugo']) expect((await call(name, 'POST', `/proposals/${rideId}/accept`)).statusCode).toBe(200);
    expect((await call('Hugo', 'GET', `/rides/${rideId}`)).statusCode).toBe(200);

    const campus = (await call('Hugo', 'GET', `/rides/${rideId}`)).json<{ stops: { kind: string; lat: number; lon: number }[] }>().stops.at(-1)!;
    const lea = user('Léa');
    const hugo = user('Hugo');
    const leg = (a: LatLon, b: LatLon) => Math.round(Math.round(distanceMeters(a, b)) / 10);
    const real = leg(lea, hugo) + leg(hugo, campus) - leg(lea, campus);
    const hugoView = await find('Hugo');
    expect(hugoView.detourMinutes).toBe(Math.ceil(real / 60));
    expect(hugoView.driver!.detourMinutes).toBe(Math.ceil(real / 60));
  });
});
