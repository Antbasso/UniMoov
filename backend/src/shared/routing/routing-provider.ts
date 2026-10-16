import type { LatLon } from '../geo.js';

/** Itinéraires routiers, derrière une interface (docs/couts.md). */
export interface RouteLeg {
  distanceM: number;
  durationS: number;
}

export interface RouteResult {
  distanceM: number;
  durationS: number;
  /** Un tronçon entre chaque paire de points consécutifs demandés. */
  legs: RouteLeg[];
  /** Tracé (au moins les points demandés). */
  geometry: LatLon[];
  /** `true` si le tracé est une estimation locale (lignes droites), pas un vrai itinéraire. */
  estimated: boolean;
}

export interface RoutingProvider {
  /** Itinéraire passant par les points donnés, dans l'ordre (au moins deux). */
  route(points: readonly LatLon[]): Promise<RouteResult>;
}

export class RoutingUnavailableError extends Error {
  override readonly name = 'RoutingUnavailableError';
}
