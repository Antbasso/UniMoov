import { z } from 'zod';
import { type Bbox, type MeetingSpot, type PlacesProvider, PlacesUnavailableError } from './places-provider.js';

const element = z.object({
  lat: z.number().optional(),
  lon: z.number().optional(),
  center: z.object({ lat: z.number(), lon: z.number() }).optional(),
  tags: z.record(z.string(), z.string()).optional(),
});
const responseSchema = z.object({ elements: z.array(element) });

/** Au plus autant de lieux par zone (les plus petits parkings d'une ville en dépassent vite). */
const MAX_RESULTS = 400;

/**
 * Données OpenStreetMap via l'API Overpass (gratuite, sans clé) : parkings ouverts au public
 * (pas les parkings privés, clients ou réservés) et aires de covoiturage.
 */
export class OverpassPlacesProvider implements PlacesProvider {
  constructor(
    private readonly url: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async meetingSpots(b: Bbox): Promise<MeetingSpot[]> {
    const box = `${b.south},${b.west},${b.north},${b.east}`;
    const query = `[out:json][timeout:15];
(
  nwr["amenity"="parking"]["access"!~"^(private|customers|no|permit|delivery|residents)$"](${box});
  nwr["amenity"="car_pooling"](${box});
);
out center ${MAX_RESULTS};`;
    let body: unknown;
    try {
      const response = await this.fetchImpl(this.url, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded', 'user-agent': 'Uni-Moov (covoiturage etudiant)' },
        body: new URLSearchParams({ data: query }).toString(),
        signal: AbortSignal.timeout(15_000),
      });
      if (!response.ok) throw new PlacesUnavailableError(`HTTP ${response.status}`);
      body = await response.json();
    } catch (error) {
      if (error instanceof PlacesUnavailableError) throw error;
      throw new PlacesUnavailableError('Service de lieux injoignable');
    }
    const parsed = responseSchema.safeParse(body);
    if (!parsed.success) throw new PlacesUnavailableError('Réponse de lieux inattendue');
    return parsed.data.elements.flatMap((e) => {
      const lat = e.lat ?? e.center?.lat;
      const lon = e.lon ?? e.center?.lon;
      if (lat === undefined || lon === undefined) return [];
      const tags = e.tags ?? {};
      const carpool = tags.amenity === 'car_pooling' || tags.carpool === 'designated';
      return [{ kind: carpool ? 'carpool' : 'parking', name: tags.name?.trim() || null, lat, lon } satisfies MeetingSpot];
    });
  }
}
