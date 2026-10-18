import { describe, expect, it, vi } from 'vitest';
import { distanceMeters } from '../../src/shared/geo.js';
import { estimateRoute } from '../../src/shared/routing/estimate.js';
import { GuardedRoutingProvider } from '../../src/shared/routing/guarded-routing-provider.js';
import { OrsRoutingProvider } from '../../src/shared/routing/ors-routing-provider.js';
import { OsrmRoutingProvider } from '../../src/shared/routing/osrm-routing-provider.js';
import { type RouteResult, type RoutingProvider, RoutingUnavailableError } from '../../src/shared/routing/routing-provider.js';

const a = { lat: 45.8865, lon: 6.089 };
const b = { lat: 45.905, lon: 6.103 };
const c = { lat: 45.9195, lon: 6.158 };
const params = { roadFactor: 1.3, avgSpeedKmh: 40 };

describe('estimateRoute', () => {
  it('distance à vol d’oiseau × facteur routier, durée à vitesse moyenne, un tronçon par paire', () => {
    const route = estimateRoute([a, b, c], params);
    expect(route.legs).toHaveLength(2);
    expect(route.distanceM).toBe(route.legs[0]!.distanceM + route.legs[1]!.distanceM);
    expect(route.legs[0]!.distanceM).toBe(Math.round(distanceMeters(a, b) * 1.3));
    expect(route.legs[0]!.durationS).toBe(Math.round(route.legs[0]!.distanceM / (40_000 / 3600)));
    expect(route.geometry).toEqual([a, b, c]);
    expect(route.estimated).toBe(true);
  });

  it('refuse moins de deux points', () => {
    expect(() => estimateRoute([a], params)).toThrow(RangeError);
  });
});

const orsBody = {
  features: [
    {
      geometry: { coordinates: [[6.089, 45.8865], [6.1, 45.9, 512.3], [6.158, 45.9195]] },
      properties: {
        summary: { distance: 9876.4, duration: 812.6 },
        segments: [
          { distance: 3000.2, duration: 250.1 },
          { distance: 6876.2, duration: 562.5 },
        ],
      },
    },
  ],
};

describe('OrsRoutingProvider', () => {
  it('envoie seulement des coordonnées [lon, lat] avec la clé en en-tête, lit tronçons et tracé', async () => {
    const fetchImpl = vi.fn(() => Promise.resolve(new Response(JSON.stringify(orsBody), { status: 200 })));
    const provider = new OrsRoutingProvider('cle-test', 'https://ors.test', fetchImpl);
    const route = await provider.route([a, b, c]);

    const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://ors.test/v2/directions/driving-car/geojson');
    expect((init.headers as Record<string, string>).Authorization).toBe('cle-test');
    expect(JSON.parse(init.body as string)).toEqual({ coordinates: [[6.089, 45.8865], [6.103, 45.905], [6.158, 45.9195]] });
    expect(route).toEqual({
      distanceM: 9876,
      durationS: 813,
      legs: [
        { distanceM: 3000, durationS: 250 },
        { distanceM: 6876, durationS: 563 },
      ],
      geometry: [a, { lat: 45.9, lon: 6.1 }, c],
      estimated: false,
    });
  });

  it('erreur HTTP, réseau ou réponse inattendue : RoutingUnavailableError', async () => {
    const cases: (() => Promise<Response>)[] = [
      () => Promise.resolve(new Response('quota', { status: 429 })),
      () => Promise.reject(new TypeError('fetch failed')),
      () => Promise.resolve(new Response(JSON.stringify({ features: [] }), { status: 200 })),
      () =>
        Promise.resolve(
          new Response(
            JSON.stringify({ features: [{ ...orsBody.features[0], properties: { summary: {}, segments: [] } }] }),
            { status: 200 },
          ),
        ),
    ];
    for (const impl of cases) {
      const provider = new OrsRoutingProvider('k', 'https://ors.test', vi.fn(impl));
      await expect(provider.route([a, b, c])).rejects.toBeInstanceOf(RoutingUnavailableError);
    }
  });
});

describe('OsrmRoutingProvider', () => {
  it('demande lon,lat dans l’ordre et lit tronçons et tracé', async () => {
    const fetchImpl = vi.fn((url: string) => {
      expect(url).toBe(
        'https://osrm.test/route/v1/driving/6.141000,45.864000;6.158000,45.919500?overview=simplified&geometries=geojson',
      );
      return Promise.resolve(
        new Response(
          JSON.stringify({
            code: 'Ok',
            routes: [
              {
                distance: 9866.9,
                duration: 998.7,
                geometry: { coordinates: [[6.141, 45.864], [6.15, 45.89], [6.158, 45.9195]] },
                legs: [{ distance: 9866.9, duration: 998.7 }],
              },
            ],
          }),
        ),
      );
    });
    const result = await new OsrmRoutingProvider('https://osrm.test', fetchImpl as unknown as typeof fetch).route([
      { lat: 45.864, lon: 6.141 },
      { lat: 45.9195, lon: 6.158 },
    ]);
    expect(result).toMatchObject({ distanceM: 9867, durationS: 999, estimated: false, legs: [{ distanceM: 9867 }] });
    expect(result.geometry[1]).toEqual({ lat: 45.89, lon: 6.15 });
  });

  it('erreur HTTP, code OSRM ou réseau : RoutingUnavailableError', async () => {
    for (const impl of [
      () => Promise.resolve(new Response('', { status: 429 })),
      () => Promise.resolve(new Response(JSON.stringify({ code: 'NoRoute', routes: [] }))),
      () => Promise.reject(new Error('réseau')),
    ]) {
      const provider = new OsrmRoutingProvider('https://osrm.test', vi.fn(impl));
      await expect(provider.route([{ lat: 1, lon: 1 }, { lat: 2, lon: 2 }])).rejects.toBeInstanceOf(RoutingUnavailableError);
    }
  });
});

describe('GuardedRoutingProvider', () => {
  const real: RouteResult = { distanceM: 1, durationS: 1, legs: [{ distanceM: 1, durationS: 1 }], geometry: [a, c], estimated: false };
  const fake = (): RoutingProvider & { calls: number } => {
    const p = { calls: 0, route: () => (p.calls++, Promise.resolve(real)) };
    return p;
  };
  const fallback: RoutingProvider = { route: (points) => Promise.resolve(estimateRoute(points, params)) };

  it('met en cache par coordonnées arrondies (~10 m)', async () => {
    const primary = fake();
    const guard = new GuardedRoutingProvider(primary, fallback, { dailyQuota: 10 });
    await guard.route([{ lat: 45.88612, lon: 6.08912 }, c]);
    await guard.route([{ lat: 45.88614, lon: 6.08914 }, c]);
    expect(primary.calls).toBe(1);
    await guard.route([b, c]);
    expect(primary.calls).toBe(2);
  });

  it('alerte à 80 % du quota, puis estimation locale au-delà, et repart le lendemain', async () => {
    let now = Date.UTC(2026, 9, 19, 8);
    const events: string[] = [];
    const primary = fake();
    const guard = new GuardedRoutingProvider(primary, fallback, {
      dailyQuota: 5,
      now: () => now,
      ttlMs: 0,
      onEvent: (e) => events.push(e),
    });
    for (let i = 0; i < 4; i++) await guard.route([{ lat: 45 + i * 0.01, lon: 6 }, c]);
    expect(events).toEqual(['quota_warning']);
    await guard.route([{ lat: 46, lon: 6 }, c]);
    const over = await guard.route([{ lat: 46.5, lon: 6 }, c]);
    expect(over.estimated).toBe(true);
    expect(primary.calls).toBe(5);
    expect(events).toContain('quota_exceeded');

    now += 24 * 60 * 60 * 1000;
    expect((await guard.route([{ lat: 47, lon: 6 }, c])).estimated).toBe(false);
  });

  it('panne du fournisseur : estimation locale, rien en cache', async () => {
    const events: string[] = [];
    let fail = true;
    const primary: RoutingProvider = {
      route: () => (fail ? Promise.reject(new RoutingUnavailableError('down')) : Promise.resolve(real)),
    };
    const guard = new GuardedRoutingProvider(primary, fallback, { dailyQuota: 10, onEvent: (e) => events.push(e) });
    expect((await guard.route([a, c])).estimated).toBe(true);
    expect(events).toEqual(['provider_error']);
    fail = false;
    expect((await guard.route([a, c])).estimated).toBe(false);
  });
});
