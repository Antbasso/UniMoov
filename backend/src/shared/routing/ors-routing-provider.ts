import { z } from 'zod';
import type { LatLon } from '../geo.js';
import { type RouteResult, type RoutingProvider, RoutingUnavailableError } from './routing-provider.js';

const responseSchema = z.object({
  features: z
    .array(
      z.object({
        geometry: z.object({ coordinates: z.array(z.tuple([z.number(), z.number()]).rest(z.number())) }),
        properties: z.object({
          summary: z.object({ distance: z.number().optional(), duration: z.number().optional() }),
          segments: z.array(z.object({ distance: z.number().optional(), duration: z.number().optional() })),
        }),
      }),
    )
    .min(1),
});

/**
 * OpenRouteService (palier gratuit, clé côté serveur uniquement). Seul le fournisseur reçoit
 * des coordonnées, jamais de nom ni d'identifiant.
 */
export class OrsRoutingProvider implements RoutingProvider {
  constructor(
    private readonly apiKey: string,
    private readonly baseUrl = 'https://api.openrouteservice.org',
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async route(points: readonly LatLon[]): Promise<RouteResult> {
    if (points.length < 2) throw new RangeError('Au moins deux points');
    let body: unknown;
    try {
      const response = await this.fetchImpl(`${this.baseUrl}/v2/directions/driving-car/geojson`, {
        method: 'POST',
        headers: { Authorization: this.apiKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({ coordinates: points.map((p) => [p.lon, p.lat]) }),
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) throw new RoutingUnavailableError(`HTTP ${response.status}`);
      body = await response.json();
    } catch (error) {
      if (error instanceof RoutingUnavailableError) throw error;
      throw new RoutingUnavailableError("Service d'itinéraires injoignable");
    }
    const parsed = responseSchema.safeParse(body);
    if (!parsed.success) throw new RoutingUnavailableError("Réponse d'itinéraire inattendue");
    const [feature] = parsed.data.features;
    const { summary, segments } = feature!.properties;
    if (segments.length !== points.length - 1) throw new RoutingUnavailableError('Tronçons inattendus');
    return {
      distanceM: Math.round(summary.distance ?? 0),
      durationS: Math.round(summary.duration ?? 0),
      legs: segments.map((s) => ({ distanceM: Math.round(s.distance ?? 0), durationS: Math.round(s.duration ?? 0) })),
      geometry: feature!.geometry.coordinates.map(([lon, lat]) => ({ lat, lon })),
      estimated: false,
    };
  }
}
