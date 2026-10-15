import { describe, expect, it } from 'vitest';
import { orderStops, passageTimes, planKey } from '../../src/modules/rides/domain.js';

const campus = { lat: 45.9195, lon: 6.158 };
const seynod = { lat: 45.8865, lon: 6.089 };
const cranGevrier = { lat: 45.905, lon: 6.103 };
const annecy = { lat: 45.8992, lon: 6.1294 };
const meythet = { lat: 45.918, lon: 6.096 };

const stop = (userId: string, point: { lat: number; lon: number }) => ({ userId, point });

describe('orderStops', () => {
  it('ramasse dans l’ordre de la route vers le campus', () => {
    const ordered = orderStops(seynod, campus, [stop('a', annecy), stop('c', cranGevrier)]);
    expect(ordered.map((s) => s.userId)).toEqual(['c', 'a']);
  });

  it('au retour, dépose dans l’ordre inverse (départ du campus)', () => {
    const ordered = orderStops(campus, seynod, [stop('c', cranGevrier), stop('a', annecy)]);
    expect(ordered.map((s) => s.userId)).toEqual(['a', 'c']);
  });

  it('trouve l’ordre optimal là où le plus proche voisin se trompe', () => {
    // Depuis le départ, le point le plus proche est en arrière : l'optimum le prend quand même au bon moment.
    const start = { lat: 0, lon: 0 };
    const end = { lat: 0, lon: 10 };
    const stops = [stop('x', { lat: 0, lon: -1 }), stop('y', { lat: 0, lon: 1.5 }), stop('z', { lat: 0, lon: 5 })];
    const ordered = orderStops(start, end, stops).map((s) => s.userId);
    expect(ordered).toEqual(['x', 'y', 'z']);
  });

  it('cas limites : aucun arrêt, un seul, arrêts confondus (ordre d’entrée conservé)', () => {
    expect(orderStops(seynod, campus, [])).toEqual([]);
    expect(orderStops(seynod, campus, [stop('a', annecy)]).map((s) => s.userId)).toEqual(['a']);
    const same = orderStops(seynod, campus, [stop('b', annecy), stop('a', annecy)]);
    expect(same.map((s) => s.userId)).toEqual(['b', 'a']);
  });

  it('au-delà de 7 arrêts, reste rapide et garde chaque arrêt une fois', () => {
    const many = Array.from({ length: 9 }, (_, i) => stop(`p${i}`, { lat: 45.9 + i * 0.002, lon: 6.1 + i * 0.003 }));
    const ordered = orderStops(seynod, campus, many);
    expect(new Set(ordered.map((s) => s.userId)).size).toBe(9);
    expect(ordered[0]!.userId).toBe('p0');
  });

  it('ne modifie pas la liste reçue', () => {
    const input = [stop('a', annecy), stop('m', meythet), stop('c', cranGevrier)];
    const copy = input.map((s) => s.userId);
    orderStops(seynod, campus, input);
    expect(input.map((s) => s.userId)).toEqual(copy);
  });
});

describe('passageTimes', () => {
  const target = new Date('2026-10-19T06:00:00Z');
  const legs = [
    { distanceM: 3000, durationS: 300 },
    { distanceM: 6000, durationS: 600 },
  ];

  it('aller : départ calculé pour arriver à l’heure cible', () => {
    const times = passageTimes('to_campus', target, legs).map((d) => d.toISOString());
    expect(times).toEqual(['2026-10-19T05:45:00.000Z', '2026-10-19T05:50:00.000Z', '2026-10-19T06:00:00.000Z']);
  });

  it('retour : départ du campus à l’heure cible', () => {
    const times = passageTimes('from_campus', target, legs).map((d) => d.toISOString());
    expect(times).toEqual(['2026-10-19T06:00:00.000Z', '2026-10-19T06:05:00.000Z', '2026-10-19T06:15:00.000Z']);
  });

  it('sans tronçon : une seule heure', () => {
    expect(passageTimes('to_campus', target, [])).toEqual([target]);
  });
});

describe('planKey', () => {
  it('ne dépend pas de l’ordre et change si un point bouge', () => {
    const a = planKey([stop('a', annecy), stop('c', cranGevrier)]);
    expect(planKey([stop('c', cranGevrier), stop('a', annecy)])).toBe(a);
    expect(planKey([stop('a', annecy), stop('c', meythet)])).not.toBe(a);
    expect(planKey([stop('a', annecy)])).not.toBe(a);
  });
});
