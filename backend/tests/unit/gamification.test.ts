import { describe, expect, it } from 'vitest';
import { badgesFor, co2SavedKg, levelFor, pointsFor, rank, type RideStats } from '../../src/modules/gamification/domain.js';

const none: RideStats = {
  ridesDriven: 0,
  ridesAsPassenger: 0,
  passengersCarried: 0,
  fiveStarRatings: 0,
  distinctCompanions: 0,
  sharedKm: 0,
  bestWeekRides: 0,
  reliability: 1,
};

describe('points et niveaux', () => {
  it('conduire rapporte plus, chaque passager en plus aussi', () => {
    expect(pointsFor({ ridesDriven: 2, passengersCarried: 5, ridesAsPassenger: 3, fiveStarRatings: 4 })).toBe(30 + 25 + 30 + 12);
    expect(pointsFor(none)).toBe(0);
  });

  it('niveau atteint au minimum exact, prochain niveau donné, aucun après le dernier', () => {
    expect(levelFor(0)).toEqual({ key: 'newcomer', min: 0, next: { key: 'regular', min: 100 } });
    expect(levelFor(99).key).toBe('newcomer');
    expect(levelFor(100).key).toBe('regular');
    expect(levelFor(700)).toMatchObject({ key: 'super', next: { key: 'legend' } });
    expect(levelFor(99_999)).toEqual({ key: 'legend', min: 1500, next: null });
  });
});

describe('impact', () => {
  it('193 g de CO₂ par km partagé, arrondi au kg ; jamais négatif', () => {
    expect(co2SavedKg(100)).toBe(19);
    expect(co2SavedKg(2)).toBe(0);
    expect(co2SavedKg(-5)).toBe(0);
  });
});

describe('badges', () => {
  it('sans trajet : rien de gagné, progression à zéro', () => {
    expect(badgesFor(none).every((b) => !b.earned && b.progress === 0)).toBe(true);
  });

  it('progression plafonnée à l’objectif ; fiable seulement avec un bon score', () => {
    const s = { ...none, ridesDriven: 12, ridesAsPassenger: 3, bestWeekRides: 5, sharedKm: 600, reliability: 0.97 };
    const byKey = new Map(badgesFor(s).map((b) => [b.key, b]));
    expect(byKey.get('first_ride')).toMatchObject({ earned: true, progress: 1 });
    expect(byKey.get('ten_rides')).toMatchObject({ earned: true, progress: 10 });
    expect(byKey.get('fifty_rides')).toMatchObject({ earned: false, progress: 15 });
    expect(byKey.get('loyal_driver')!.earned).toBe(true);
    expect(byKey.get('full_week')!.earned).toBe(true);
    expect(byKey.get('eco')).toMatchObject({ earned: true, progress: 100 }); // 115 kg
    expect(byKey.get('reliable')!.earned).toBe(true);
    expect(new Map(badgesFor({ ...s, reliability: 0.9 }).map((b) => [b.key, b])).get('reliable')!.progress).toBe(0);
  });
});

describe('classement', () => {
  it('points décroissants, ex æquo au même rang, ordre stable', () => {
    const ranked = rank([
      { userId: 'c', points: 10 },
      { userId: 'a', points: 30 },
      { userId: 'b', points: 10 },
      { userId: 'd', points: 0 },
    ]);
    expect(ranked.map((r) => [r.userId, r.rank])).toEqual([['a', 1], ['b', 2], ['c', 2], ['d', 4]]);
    expect(rank([])).toEqual([]);
  });
});
