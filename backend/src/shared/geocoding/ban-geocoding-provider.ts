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
  ) {}

  async geocode(query: string): Promise<GeocodedAddress | null> {
    const url = new URL(this.baseUrl);
    url.searchParams.set('q', query);
    url.searchParams.set('limit', '1');
    url.searchParams.set('index', 'address');

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
    const best = parsed.data.features[0];
    if (!best || best.properties.score < MIN_SCORE) return null;
    const [lon, lat] = best.geometry.coordinates;
    return { label: best.properties.label, lat, lon };
  }
}
