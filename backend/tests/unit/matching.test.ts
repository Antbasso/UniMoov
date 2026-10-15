import { describe, expect, it } from 'vitest';
import {
  assignRoles,
  detourSeconds,
  isTimeCompatible,
  matchSlot,
  type MatchParams,
  type Need,
  pickupOrder,
  rankCandidates,
} from '../../src/modules/matching/domain.js';

const params: MatchParams = {
  campus: { lat: 45.9195, lon: 6.158 },
  roadFactor: 1.3,
  avgSpeedKmh: 40,
  arrivalWindowMinutes: 30,
};

// Repères réels autour d'Annecy.
const places = {
  seynod: { lat: 45.8865, lon: 6.089 },
  cranGevrier: { lat: 45.905, lon: 6.103 }, // sur la route Seynod → campus
  meythet: { lat: 45.918, lon: 6.096 }, // un peu au nord de la route
  annecy: { lat: 45.8992, lon: 6.1294 },
  sevrier: { lat: 45.864, lon: 6.141 }, // à l'opposé, au sud du lac
  rumilly: { lat: 45.8667, lon: 5.944 }, // loin à l'ouest
};

const at = (hhmm: string) => new Date(`2026-10-12T${hhmm}:00Z`);

function need(userId: string, home: keyof typeof places, overrides: Partial<Need> = {}): Need {
  return {
    userId,
    home: places[home],
    time: at('07:00'),
    roleMode: 'always_passenger',
    vehicle: null,
    reliability: 0.8,
    ...overrides,
  };
}

const driver = (userId: string, home: keyof typeof places, seats = 3, maxDetourMinutes = 10, overrides: Partial<Need> = {}) =>
  need(userId, home, { roleMode: 'always_driver', vehicle: { seats, maxDetourMinutes }, ...overrides });

describe('assignRoles', () => {
  it('sans véhicule : passager, même en mode automatique', () => {
    const roles = assignRoles([need('a', 'annecy', { roleMode: 'auto' })]);
    expect(roles.get('a')).toBe('passenger');
  });

  it('modes forcés respectés', () => {
    const roles = assignRoles([driver('d', 'seynod'), need('p', 'annecy')]);
    expect(roles.get('d')).toBe('driver');
    expect(roles.get('p')).toBe('passenger');
  });

  it('deux automatiques seuls : l’un conduit, l’autre est passager', () => {
    const roles = assignRoles([
      need('a', 'seynod', { roleMode: 'auto', vehicle: { seats: 3, maxDetourMinutes: 10 } }),
      need('b', 'annecy', { roleMode: 'auto', vehicle: { seats: 3, maxDetourMinutes: 10 } }),
    ]);
    expect([...roles.values()].sort()).toEqual(['driver', 'passenger']);
  });

  it('automatique : la plus grande voiture conduit en premier', () => {
    const roles = assignRoles([
      need('p1', 'annecy'),
      need('p2', 'meythet'),
      need('p3', 'cranGevrier'),
      need('small', 'seynod', { roleMode: 'auto', vehicle: { seats: 2, maxDetourMinutes: 10 } }),
      need('big', 'sevrier', { roleMode: 'auto', vehicle: { seats: 4, maxDetourMinutes: 10 } }),
    ]);
    expect(roles.get('big')).toBe('driver');
    expect(roles.get('small')).toBe('passenger');
  });

  it('automatique : ne conduit pas si les conducteurs forcés suffisent', () => {
    const roles = assignRoles([
      driver('d', 'seynod', 4),
      need('p', 'annecy'),
      need('a', 'meythet', { roleMode: 'auto', vehicle: { seats: 3, maxDetourMinutes: 10 } }),
    ]);
    expect(roles.get('a')).toBe('passenger');
  });
});

describe('détour estimé', () => {
  it('nul sans passager, faible sur la route, fort à l’opposé', () => {
    expect(detourSeconds(places.seynod, [], params)).toBe(0);
    const onTheWay = detourSeconds(places.seynod, [places.cranGevrier], params);
    const opposite = detourSeconds(places.seynod, [places.sevrier], params);
    expect(onTheWay).toBeLessThan(120);
    expect(opposite).toBeGreaterThan(4 * onTheWay);
  });

  it('applique le facteur routier et la vitesse moyenne', () => {
    const slow = detourSeconds(places.seynod, [places.sevrier], { ...params, avgSpeedKmh: 20 });
    expect(slow).toBeCloseTo(2 * detourSeconds(places.seynod, [places.sevrier], params), 5);
  });

  it('ordre de ramassage : le plus proche d’abord', () => {
    const order = pickupOrder(places.seynod, [
      { id: 'meythet', home: places.meythet },
      { id: 'cran', home: places.cranGevrier },
    ]);
    expect(order.map((o) => o.id)).toEqual(['cran', 'meythet']);
  });
});

describe('isTimeCompatible', () => {
  it('écart de 30 minutes accepté, 31 refusé', () => {
    expect(isTimeCompatible(at('07:00'), at('07:30'), params)).toBe(true);
    expect(isTimeCompatible(at('07:31'), at('07:00'), params)).toBe(false);
  });
});

describe('rankCandidates', () => {
  const passenger = need('p', 'cranGevrier');

  it('classe par détour puis par fiabilité du conducteur', () => {
    const ranked = rankCandidates(
      passenger,
      [driver('far', 'annecy', 3, 30), driver('nearLow', 'seynod', 3, 30, { reliability: 0.5 })],
      params,
    );
    expect(ranked.map((c) => c.driver.userId)[0]).toBe('nearLow');
    const tie = rankCandidates(
      passenger,
      [driver('b', 'seynod', 3, 30, { reliability: 0.6 }), driver('a', 'seynod', 3, 30, { reliability: 0.9 })],
      params,
    );
    expect(tie.map((c) => c.driver.userId)).toEqual(['a', 'b']);
  });

  it('écarte le détour au-dessus du seuil, l’horaire incompatible et les refus', () => {
    expect(rankCandidates(need('s', 'sevrier'), [driver('d', 'seynod', 3, 5)], params)).toEqual([]);
    expect(rankCandidates({ ...passenger, time: at('09:00') }, [driver('d', 'seynod')], params)).toEqual([]);
    expect(rankCandidates(passenger, [driver('d', 'seynod')], params, (d, p) => d === 'd' && p === 'p')).toEqual([]);
  });

  it('ne propose jamais un passager à lui-même', () => {
    const self = need('x', 'seynod', { roleMode: 'auto', vehicle: { seats: 3, maxDetourMinutes: 10 } });
    expect(rankCandidates(self, [self], params)).toEqual([]);
  });
});

describe('matchSlot', () => {
  it('cas vide et sans conducteur', () => {
    expect(matchSlot([], 'to_campus', params)).toEqual({ rides: [], unmatched: [] });
    expect(matchSlot([need('p', 'annecy')], 'to_campus', params)).toEqual({ rides: [], unmatched: ['p'] });
  });

  it('respecte le nombre de places', () => {
    const { rides, unmatched } = matchSlot(
      [driver('d', 'seynod', 1, 30), need('p1', 'cranGevrier'), need('p2', 'meythet')],
      'to_campus',
      params,
    );
    expect(rides).toHaveLength(1);
    expect(rides[0]!.passengers.map((p) => p.userId)).toEqual(['p1']); // plus court détour
    expect(unmatched).toEqual(['p2']);
  });

  it('conflit à détour égal : le passager le plus fiable gagne', () => {
    const { rides } = matchSlot(
      [
        driver('d', 'seynod', 1, 30),
        need('low', 'cranGevrier', { reliability: 0.4 }),
        need('high', 'cranGevrier', { reliability: 0.95 }),
      ],
      'to_campus',
      params,
    );
    expect(rides[0]!.passengers.map((p) => p.userId)).toEqual(['high']);
  });

  it('le détour cumulé reste sous le seuil du conducteur', () => {
    const single = detourSeconds(places.seynod, [places.meythet], params);
    const both = detourSeconds(places.seynod, [places.meythet, places.annecy], params);
    const thresholdMinutes = Math.ceil(single / 60) + 1;
    expect(both).toBeGreaterThan(thresholdMinutes * 60);
    const { rides, unmatched } = matchSlot(
      [driver('d', 'seynod', 3, thresholdMinutes), need('m', 'meythet'), need('a', 'annecy')],
      'to_campus',
      params,
    );
    expect(rides[0]!.totalDetourSeconds).toBeLessThanOrEqual(thresholdMinutes * 60);
    expect(rides[0]!.passengers).toHaveLength(1);
    expect(unmatched).toHaveLength(1);
  });

  it.each(['cranGevrier', 'meythet', 'annecy', 'sevrier'] as const)(
    'passager à %s : attribué au conducteur au plus court détour',
    (home) => {
      const drivers = [driver('west', 'rumilly', 3, 60), driver('south', 'seynod', 3, 60)];
      const best = drivers
        .map((d) => ({ id: d.userId, detour: detourSeconds(d.home, [places[home]], params) }))
        .sort((a, b) => a.detour - b.detour)[0]!.id;
      const { rides } = matchSlot([...drivers, need('p', home)], 'to_campus', params);
      expect(rides.map((r) => r.driverId)).toEqual([best]);
    },
  );

  it('heure cible : arrivée avant le premier cours, départ après le dernier', () => {
    const needs = [driver('d', 'seynod', 3, 30, { time: at('07:15') }), need('p', 'cranGevrier', { time: at('07:00') })];
    expect(matchSlot(needs, 'to_campus', params).rides[0]!.targetTime).toEqual(at('07:00'));
    expect(matchSlot(needs, 'from_campus', params).rides[0]!.targetTime).toEqual(at('07:15'));
  });

  it('le détour propre à chaque passager ne dépasse pas le total', () => {
    const { rides } = matchSlot(
      [driver('d', 'seynod', 3, 30), need('a', 'cranGevrier'), need('b', 'meythet')],
      'to_campus',
      params,
    );
    const ride = rides[0]!;
    expect(ride.passengers).toHaveLength(2);
    for (const p of ride.passengers) expect(p.detourSeconds).toBeLessThanOrEqual(ride.totalDetourSeconds + 1e-6);
  });

  it('est déterministe quel que soit l’ordre d’entrée', () => {
    const needs = [driver('d', 'seynod', 2, 30), need('a', 'cranGevrier'), need('b', 'meythet'), need('c', 'annecy')];
    expect(matchSlot([...needs].reverse(), 'to_campus', params)).toEqual(matchSlot(needs, 'to_campus', params));
  });
});
