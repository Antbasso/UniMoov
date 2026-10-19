import { z } from 'zod';
import {
  type GeocodedAddress,
  type GeocodingProvider,
  GeocodingUnavailableError,
} from './geocoding-provider.js';

const MIN_SCORE = 0.5;

const responseSchema = z.object({
  features: z.array(
    z.object({
      geometry: z.object({ coordinates: z.tuple([z.number(), z.number()]) }),
      properties: z.object({ label: z.string(), score: z.number() }),
    }),
  ),
});

/** Base Adresse Nationale via la Géoplateforme (gratuite, sans clé). */
export class BanGeocodingProvider implements GeocodingProvider {
  constructor(
    private readonly baseUrl: string,
    private readonly fetchImpl: typeof fetch = fetch,
    /** Résultats proches de ce point d'abord (campus du pilote). */
    private readonly focus?: { lat: number; lon: number },
  ) {}

  async geocode(query: string): Promise<GeocodedAddress | null> {
    const best = (await this.search(query, 1, false))[0];
    if (!best || best.score < MIN_SCORE) return null;
    return { label: best.label, lat: best.lat, lon: best.lon };
  }

  async suggest(query: string, limit: number): Promise<GeocodedAddress[]> {
    const results = await this.search(query, limit, true);
    return results.map(({ label, lat, lon }) => ({ label, lat, lon }));
  }

  private async search(query: string, limit: number, autocomplete: boolean) {
    const url = new URL(this.baseUrl);
    url.searchParams.set('q', query);
    url.searchParams.set('limit', String(limit));
    url.searchParams.set('index', 'address');
    if (autocomplete) url.searchParams.set('autocomplete', '1');
    if (this.focus) {
      url.searchParams.set('lat', String(this.focus.lat));
      url.searchParams.set('lon', String(this.focus.lon));
    }

    let body: unknown;
    try {
      const response = await this.fetchImpl(url, { signal: AbortSignal.timeout(5000) });
      if (!response.ok) throw new GeocodingUnavailableError(`HTTP ${response.status}`);
      body = await response.json();
    } catch (error) {
      if (error instanceof GeocodingUnavailableError) throw error;
      throw new GeocodingUnavailableError('Service de géocodage injoignable');
    }

    const parsed = responseSchema.safeParse(body);
    if (!parsed.success) throw new GeocodingUnavailableError('Réponse de géocodage inattendue');
    return parsed.data.features.map((f) => ({
      label: f.properties.label,
      lat: f.geometry.coordinates[1],
      lon: f.geometry.coordinates[0],
      score: f.properties.score,
    }));
  }
}
