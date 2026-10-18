import { describe, expect, it } from 'vitest';
import { estimatePrice, proRataPrice } from '../../src/modules/pricing/domain.js';

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

describe('proRataPrice', () => {
  // 10 km à 6 L/100 km et 1,80 €/L : 108 centimes de carburant.
  const base = { consumptionLPer100km: 6, fuelPriceCentsPerLitre: 180, distanceM: 10_000, commissionCentsPerPassenger: 20 };

  it('seul passager sur tout le trajet : la moitié du coût, comme le partage simple', () => {
    const price = proRataPrice({ ...base, onboardM: [10_000] });
    expect(price.totalCostCents).toBe(108);
    expect(price.sharesCents).toEqual([54]);
    expect(price.driverReceivesCents).toBe(54);
    expect(proRataPrice({ ...base, onboardM: [null] }).sharesCents).toEqual([54]);
  });

  it('pris à mi-chemin : ne paie que la moitié qu’il fait, partagée en deux', () => {
    expect(proRataPrice({ ...base, onboardM: [5_000] }).sharesCents).toEqual([27]);
  });

  it('deux passagers : la portion commune est partagée à trois', () => {
    // A monte au départ (10 km), B à mi-chemin (5 km).
    // 0–5 km depuis le campus : 54 c à trois (18 chacun) ; 5–10 km : 54 c à deux (27 pour A).
    const price = proRataPrice({ ...base, onboardM: [10_000, 5_000] });
    expect(price.sharesCents).toEqual([45, 18]);
    expect(price.driverReceivesCents).toBe(63);
    // Le conducteur paie le reste : jamais plus que s'il était seul.
    expect(price.totalCostCents - price.driverReceivesCents).toBeLessThanOrEqual(108);
  });

  it('portions détaillées : longueurs qui couvrent le trajet, et qui est à bord', () => {
    const price = proRataPrice({ ...base, onboardM: [10_000, 5_000] });
    expect(price.portions).toEqual([
      { distanceM: 5_000, riders: [0, 1] },
      { distanceM: 5_000, riders: [0] },
    ]);
    const partial = proRataPrice({ ...base, onboardM: [4_000] });
    expect(partial.portions).toEqual([
      { distanceM: 4_000, riders: [0] },
      { distanceM: 6_000, riders: [] },
    ]);
  });

  it('même point de montée : même part ; distances bornées au trajet', () => {
    const price = proRataPrice({ ...base, onboardM: [4_000, 4_000, 99_000, -5] });
    expect(price.sharesCents[0]).toBe(price.sharesCents[1]);
    expect(price.sharesCents[3]).toBe(0);
    expect(price.sharesCents[2]).toBeGreaterThan(price.sharesCents[0]!);
  });

  it('arrondi au centime supérieur, jamais de flottant', () => {
    const price = proRataPrice({ ...base, distanceM: 7_777, onboardM: [3_333, 7_777] });
    for (const c of price.sharesCents) expect(Number.isInteger(c)).toBe(true);
    expect(price.driverReceivesCents).toBeGreaterThanOrEqual(0);
  });

  it('refuse les valeurs invalides', () => {
    expect(() => proRataPrice({ ...base, distanceM: -1, onboardM: [] })).toThrow(RangeError);
    expect(() => proRataPrice({ ...base, commissionCentsPerPassenger: 1.5, onboardM: [] })).toThrow(RangeError);
  });
});
