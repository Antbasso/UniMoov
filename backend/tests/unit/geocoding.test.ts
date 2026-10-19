import { describe, expect, it, vi } from 'vitest';
import { BanGeocodingProvider } from '../../src/shared/geocoding/ban-geocoding-provider.js';
import { CachedGeocodingProvider } from '../../src/shared/geocoding/cached-geocoding-provider.js';
import { GeocodingUnavailableError } from '../../src/shared/geocoding/geocoding-provider.js';
import { maskEmail } from '../../src/shared/mail/mail-provider.js';

const feature = (score: number) => ({
  features: [
    { geometry: { coordinates: [6.1251, 45.9003] }, properties: { label: '12 Rue de la Paix 74000 Annecy', score } },
  ],
});

const fetchReturning = (body: unknown, status = 200) =>
  vi.fn(() => Promise.resolve(new Response(JSON.stringify(body), { status }))) as unknown as typeof fetch;

describe('BanGeocodingProvider', () => {
  it('renvoie le meilleur résultat (lat/lon dans le bon ordre)', async () => {
    const fetchImpl = fetchReturning(feature(0.9));
    const provider = new BanGeocodingProvider('https://geo.test/search', fetchImpl);
    expect(await provider.geocode('12 rue de la paix annecy')).toEqual({
      label: '12 Rue de la Paix 74000 Annecy',
      lat: 45.9003,
      lon: 6.1251,
    });
    const url = String((fetchImpl as unknown as { mock: { calls: [URL][] } }).mock.calls[0]![0]);
    expect(url).toContain('q=12+rue+de+la+paix+annecy');
    expect(url).toContain('limit=1');
  });

  it('ignore un résultat trop incertain', async () => {
    expect(await new BanGeocodingProvider('https://geo.test', fetchReturning(feature(0.3))).geocode('x')).toBeNull();
  });

  it('renvoie null sans résultat', async () => {
    expect(await new BanGeocodingProvider('https://geo.test', fetchReturning({ features: [] })).geocode('x')).toBeNull();
  });

  it('signale un service indisponible', async () => {
    await expect(new BanGeocodingProvider('https://geo.test', fetchReturning({}, 500)).geocode('x')).rejects.toThrow(
      GeocodingUnavailableError,
    );
    const failing = vi.fn(() => Promise.reject(new Error('net'))) as unknown as typeof fetch;
    await expect(new BanGeocodingProvider('https://geo.test', failing).geocode('x')).rejects.toThrow(
      GeocodingUnavailableError,
    );
  });
});

describe('BanGeocodingProvider.suggest', () => {
  it('autocomplétion près du campus, plusieurs propositions, même sous le seuil de confiance', async () => {
    let requested = '';
    const fetchImpl = vi.fn((url: URL) => {
      requested = url.toString();
      return Promise.resolve(new Response(JSON.stringify(feature(0.3))));
    }) as unknown as typeof fetch;
    const provider = new BanGeocodingProvider('https://geo.test/search', fetchImpl, { lat: 45.9195, lon: 6.158 });
    expect(await provider.suggest('12 rue de la p', 5)).toEqual([{ label: '12 Rue de la Paix 74000 Annecy', lat: 45.9003, lon: 6.1251 }]);
    const params = new URL(requested).searchParams;
    expect(Object.fromEntries(params)).toMatchObject({ autocomplete: '1', limit: '5', lat: '45.9195', lon: '6.158' });
  });
});

describe('CachedGeocodingProvider', () => {
  it('n’appelle le fournisseur qu’une fois par adresse (casse et espaces ignorés)', async () => {
    const inner = { geocode: vi.fn(() => Promise.resolve({ label: 'A', lat: 1, lon: 2 })), suggest: vi.fn(() => Promise.resolve([])) };
    const cached = new CachedGeocodingProvider(inner);
    await cached.geocode('12 rue de la Paix');
    await cached.geocode('  12 RUE de la   paix ');
    expect(inner.geocode).toHaveBeenCalledTimes(1);
  });

  it('expire les entrées et borne sa taille', async () => {
    let now = 0;
    const inner = { geocode: vi.fn(() => Promise.resolve(null)), suggest: vi.fn(() => Promise.resolve([])) };
    const cached = new CachedGeocodingProvider(inner, 2, 1000, () => now);
    await cached.geocode('a');
    now = 2000;
    await cached.geocode('a');
    expect(inner.geocode).toHaveBeenCalledTimes(2);
    await cached.geocode('b');
    await cached.geocode('c'); // évince « a »
    await cached.geocode('a');
    expect(inner.geocode).toHaveBeenCalledTimes(5);
  });
});

describe('maskEmail', () => {
  it('ne garde que la première lettre', () => {
    expect(maskEmail('lea.martin@etu.univ-smb.fr')).toBe('l***@etu.univ-smb.fr');
  });
});
