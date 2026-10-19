import { describe, expect, it } from 'vitest';
import { PlacesService } from '../../src/modules/places/service.js';
import { CachedPlacesProvider } from '../../src/shared/places/cached-places-provider.js';
import { FakePlacesProvider } from '../../src/shared/places/fake-places-provider.js';
import { OverpassPlacesProvider } from '../../src/shared/places/overpass-places-provider.js';
import { type Bbox, PlacesUnavailableError } from '../../src/shared/places/places-provider.js';

const annecy: Bbox = { south: 45.88, west: 6.08, north: 45.91, east: 6.14 };

const json = (body: unknown, status = 200) => () => Promise.resolve(new Response(JSON.stringify(body), { status }));

describe('OverpassPlacesProvider', () => {
  it('lit parkings (nœuds et surfaces via leur centre) et aires de covoiturage', async () => {
    const provider = new OverpassPlacesProvider(
      'https://overpass.test/api',
      json({
        elements: [
          { type: 'node', lat: 45.9, lon: 6.1, tags: { amenity: 'parking', name: ' Parking Bonlieu ' } },
          { type: 'way', center: { lat: 45.89, lon: 6.09 }, tags: { amenity: 'car_pooling' } },
          { type: 'way', center: { lat: 45.88, lon: 6.11 }, tags: { amenity: 'parking', carpool: 'designated' } },
          { type: 'relation', tags: { amenity: 'parking' } },
        ],
      }),
    );
    expect(await provider.meetingSpots(annecy)).toEqual([
      { kind: 'parking', name: 'Parking Bonlieu', lat: 45.9, lon: 6.1 },
      { kind: 'carpool', name: null, lat: 45.89, lon: 6.09 },
      { kind: 'carpool', name: null, lat: 45.88, lon: 6.11 },
    ]);
  });

  it('service en panne ou réponse inattendue : indisponible', async () => {
    await expect(new OverpassPlacesProvider('https://overpass.test/api', json({}, 429)).meetingSpots(annecy)).rejects.toThrow(
      PlacesUnavailableError,
    );
    await expect(new OverpassPlacesProvider('https://overpass.test/api', json({ nope: 1 })).meetingSpots(annecy)).rejects.toThrow(
      PlacesUnavailableError,
    );
    const offline = () => Promise.reject(new TypeError('fetch failed'));
    await expect(new OverpassPlacesProvider('https://overpass.test/api', offline).meetingSpots(annecy)).rejects.toThrow(
      PlacesUnavailableError,
    );
  });
});

describe('CachedPlacesProvider', () => {
  it('une zone voisine (même case de la grille) ne relance pas de requête ; résultat filtré', async () => {
    const inner = new FakePlacesProvider();
    const cached = new CachedPlacesProvider(inner);
    const first = await cached.meetingSpots(annecy);
    const nudged = await cached.meetingSpots({ ...annecy, south: 45.881, north: 45.905 });
    expect(inner.calls).toBe(1);
    expect(first.length).toBeGreaterThan(nudged.length - 1);
    expect(nudged.every((s) => s.lat >= 45.881 && s.lat <= 45.905)).toBe(true);
  });

  it('expire après une semaine', async () => {
    let now = 0;
    const inner = new FakePlacesProvider();
    const cached = new CachedPlacesProvider(inner, 10, 1000, () => now);
    await cached.meetingSpots(annecy);
    now = 1001;
    await cached.meetingSpots(annecy);
    expect(inner.calls).toBe(2);
  });
});

describe('PlacesService', () => {
  it('sans fournisseur ou fournisseur en panne : liste vide, carte utilisable', async () => {
    expect(await new PlacesService(null).meetingSpots(annecy)).toEqual({ spots: [], available: false });
    const down = { meetingSpots: () => Promise.reject(new PlacesUnavailableError('HTTP 504')) };
    expect(await new PlacesService(down).meetingSpots(annecy)).toEqual({ spots: [], available: false });
  });
});
