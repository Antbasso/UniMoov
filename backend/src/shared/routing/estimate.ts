import { distanceMeters, type LatLon } from '../geo.js';
import type { RouteResult, RoutingProvider } from './routing-provider.js';

export interface EstimateParams {
  /** Rapport entre distance routière et distance à vol d'oiseau. */
  roadFactor: number;
  avgSpeedKmh: number;
}

/**
 * Itinéraire estimé sans appel externe : lignes droites, distance × facteur routier,
 * vitesse moyenne (docs/couts.md). Sert de secours quand le fournisseur est indisponible.
 */
export function estimateRoute(points: readonly LatLon[], params: EstimateParams): RouteResult {
  if (points.length < 2) throw new RangeError('Au moins deux points');
  const speed = (params.avgSpeedKmh * 1000) / 3600;
  const legs = points.slice(1).map((point, i) => {
    const distanceM = Math.round(distanceMeters(points[i]!, point) * params.roadFactor);
    return { distanceM, durationS: Math.round(distanceM / speed) };
  });
  return {
    distanceM: legs.reduce((sum, leg) => sum + leg.distanceM, 0),
    durationS: legs.reduce((sum, leg) => sum + leg.durationS, 0),
    legs,
    geometry: [...points],
    estimated: true,
  };
}

export class EstimateRoutingProvider implements RoutingProvider {
  constructor(private readonly params: () => Promise<EstimateParams>) {}

  async route(points: readonly LatLon[]): Promise<RouteResult> {
    return estimateRoute(points, await this.params());
  }
}
