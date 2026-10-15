import type { GeocodedAddress, GeocodingProvider } from './geocoding-provider.js';

/** Tests et développement hors ligne : quelques adresses connues autour d'Annecy. */
export const FAKE_ADDRESSES: Record<string, GeocodedAddress> = {
  '12 rue de la paix annecy': { label: '12 Rue de la Paix 74000 Annecy', lat: 45.9003, lon: 6.1251 },
  '1 place de l hotel de ville seynod': {
    label: '1 Place de l’Hôtel de Ville 74600 Annecy',
    lat: 45.8865,
    lon: 6.089,
  },
};

export class FakeGeocodingProvider implements GeocodingProvider {
  calls = 0;

  geocode(query: string): Promise<GeocodedAddress | null> {
    this.calls++;
    const key = query
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9 ]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    return Promise.resolve(FAKE_ADDRESSES[key] ?? null);
  }
}
