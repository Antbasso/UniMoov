import { describe, expect, it } from 'vitest';
import { distanceMeters, SECTOR_SIZE_M, sectorCenter, sectorOf } from '../../src/shared/geo.js';

const campus = { lat: 45.9195, lon: 6.158 };

describe('sectorOf / sectorCenter', () => {
  it('est déterministe', () => {
    expect(sectorOf(campus)).toBe(sectorOf({ ...campus }));
  });

  it('place le point dans une cellule dont le centre est à moins d’une demi-diagonale', () => {
    const center = sectorCenter(sectorOf(campus));
    expect(distanceMeters(campus, center)).toBeLessThanOrEqual((SECTOR_SIZE_M * Math.SQRT2) / 2 + 1);
  });

  it('le centre d’une cellule appartient à cette cellule', () => {
    const sector = sectorOf(campus);
    expect(sectorOf(sectorCenter(sector))).toBe(sector);
  });

  it('sépare deux points distants de plus d’un kilomètre', () => {
    expect(sectorOf(campus)).not.toBe(sectorOf({ lat: campus.lat + 0.01, lon: campus.lon }));
  });

  it('gère les coordonnées négatives', () => {
    const point = { lat: -33.8688, lon: -151.2093 };
    expect(sectorOf(sectorCenter(sectorOf(point)))).toBe(sectorOf(point));
  });

  it.each([
    [{ lat: 91, lon: 0 }],
    [{ lat: 89, lon: 0 }],
    [{ lat: 0, lon: 181 }],
    [{ lat: Number.NaN, lon: 0 }],
  ])('refuse %o', (point) => {
    expect(() => sectorOf(point)).toThrow(RangeError);
  });

  it('refuse un identifiant de secteur mal formé', () => {
    expect(() => sectorCenter('12;34')).toThrow(RangeError);
  });
});

describe('distanceMeters', () => {
  it('vaut zéro pour un même point', () => {
    expect(distanceMeters(campus, campus)).toBe(0);
  });

  it('mesure un degré de latitude à environ 111 km', () => {
    expect(distanceMeters({ lat: 45, lon: 6 }, { lat: 46, lon: 6 })).toBeCloseTo(111_195, -2);
  });
});
