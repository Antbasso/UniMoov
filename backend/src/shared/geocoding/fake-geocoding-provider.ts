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

const normalize = (query: string) =>
  query
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

export class FakeGeocodingProvider implements GeocodingProvider {
  calls = 0;

  geocode(query: string): Promise<GeocodedAddress | null> {
    this.calls++;
    const key = normalize(query);
    // Une adresse proposée (son libellé exact) est aussi reconnue.
    const byLabel = Object.values(FAKE_ADDRESSES).find((a) => normalize(a.label) === key);
    return Promise.resolve(FAKE_ADDRESSES[key] ?? byLabel ?? null);
  }

  suggest(query: string, limit: number): Promise<GeocodedAddress[]> {
    const words = normalize(query).split(' ');
    return Promise.resolve(
      Object.values(FAKE_ADDRESSES)
        .filter((a) => words.every((w) => normalize(a.label).includes(w)))
        .slice(0, limit),
    );
  }
}
