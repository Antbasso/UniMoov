import { describe, expect, it } from 'vitest';
import { estimatePrice } from '../../src/modules/pricing/domain.js';

const base = {
  consumptionLPer100km: 6,
  distanceM: 20_000,
  fuelPriceCentsPerLitre: 180,
  commissionCentsPerPassenger: 20,
};

describe('estimatePrice', () => {
  it('coût = consommation × distance × prix du carburant, partagé conducteur compris', () => {
    // 6 L/100 km × 20 km = 1,2 L × 1,80 € = 2,16 €, à trois : 72 c chacun.
    const price = estimatePrice({ ...base, persons: 3 });
    expect(price).toEqual({
      totalCostCents: 216,
      persons: 3,
      shareCents: 72,
      commissionCents: 20,
      passengerPaysCents: 92,
      driverReceivesCents: 144,
    });
  });

  it('arrondit la part au centime supérieur : le conducteur ne perd rien', () => {
    const price = estimatePrice({ ...base, persons: 4 }); // 216 / 4 = 54
    expect(price.shareCents).toBe(54);
    const odd = estimatePrice({ ...base, distanceM: 20_100, persons: 3 }); // 217,08 → 217 / 3
    expect(odd.totalCostCents).toBe(217);
    expect(odd.shareCents).toBe(73);
    expect(odd.shareCents * odd.persons).toBeGreaterThanOrEqual(odd.totalCostCents);
  });

  it('ne renvoie que des entiers, même avec une consommation décimale', () => {
    const price = estimatePrice({ ...base, consumptionLPer100km: 5.7, distanceM: 13_337, persons: 2 });
    for (const value of Object.values(price)) expect(Number.isInteger(value)).toBe(true);
  });

  it('plus de passagers, prix par personne plus bas (simulation conducteur)', () => {
    const two = estimatePrice({ ...base, persons: 2 });
    const three = estimatePrice({ ...base, distanceM: 22_000, persons: 3 });
    expect(three.passengerPaysCents).toBeLessThan(two.passengerPaysCents);
  });

  it('conducteur seul : il paie tout, ne reçoit rien', () => {
    const price = estimatePrice({ ...base, persons: 1 });
    expect(price.shareCents).toBe(216);
    expect(price.driverReceivesCents).toBe(0);
  });

  it('distance nulle : prix nul hors commission', () => {
    const price = estimatePrice({ ...base, distanceM: 0, persons: 2 });
    expect(price.totalCostCents).toBe(0);
    expect(price.passengerPaysCents).toBe(20);
  });

  it('refuse les entrées invalides', () => {
    expect(() => estimatePrice({ ...base, persons: 0 })).toThrow(RangeError);
    expect(() => estimatePrice({ ...base, persons: 1.5 })).toThrow(RangeError);
    expect(() => estimatePrice({ ...base, distanceM: -1, persons: 2 })).toThrow(RangeError);
    expect(() => estimatePrice({ ...base, fuelPriceCentsPerLitre: Number.NaN, persons: 2 })).toThrow(RangeError);
    expect(() => estimatePrice({ ...base, commissionCentsPerPassenger: 0.5, persons: 2 })).toThrow(RangeError);
  });
});
