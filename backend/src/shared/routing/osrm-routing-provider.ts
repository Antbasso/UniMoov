import { z } from 'zod';
import type { LatLon } from '../geo.js';
import { type RouteResult, type RoutingProvider, RoutingUnavailableError } from './routing-provider.js';

const responseSchema = z.object({
  code: z.literal('Ok'),
  routes: z
    .array(
      z.object({
        distance: z.number(),
        duration: z.number(),
        geometry: z.object({ coordinates: z.array(z.tuple([z.number(), z.number()]).rest(z.number())) }),
        legs: z.array(z.object({ distance: z.number(), duration: z.number() })),
      }),
    )
    .min(1),
});

/**
 * OSRM (plan B de docs/architecture.md, sans clé) : instance auto-hébergée en production,
 * serveur de démonstration public en développement. Seules des coordonnées partent.
 */
export class OsrmRoutingProvider implements RoutingProvider {
  constructor(
    private readonly baseUrl: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async route(points: readonly LatLon[]): Promise<RouteResult> {
    if (points.length < 2) throw new RangeError('Au moins deux points');
    const coordinates = points.map((p) => `${p.lon.toFixed(6)},${p.lat.toFixed(6)}`).join(';');
    let body: unknown;
    try {
      const response = await this.fetchImpl(
        `${this.baseUrl}/route/v1/driving/${coordinates}?overview=simplified&geometries=geojson`,
        { headers: { 'User-Agent': 'Uni-Moov (unimoov.support@gmail.com)' }, signal: AbortSignal.timeout(8000) },
      );
      if (!response.ok) throw new RoutingUnavailableError(`HTTP ${response.status}`);
      body = await response.json();
    } catch (error) {
      if (error instanceof RoutingUnavailableError) throw error;
      throw new RoutingUnavailableError("Service d'itinéraires injoignable");
    }
    const parsed = responseSchema.safeParse(body);
    if (!parsed.success) throw new RoutingUnavailableError("Réponse d'itinéraire inattendue");
    const [route] = parsed.data.routes;
    if (route!.legs.length !== points.length - 1) throw new RoutingUnavailableError('Tronçons inattendus');
    return {
      distanceM: Math.round(route!.distance),
      durationS: Math.round(route!.duration),
      legs: route!.legs.map((l) => ({ distanceM: Math.round(l.distance), durationS: Math.round(l.duration) })),
      geometry: route!.geometry.coordinates.map(([lon, lat]) => ({ lat, lon })),
      estimated: false,
    };
  }
}
