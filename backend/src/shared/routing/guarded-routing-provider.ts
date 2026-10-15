import type { LatLon } from '../geo.js';
import type { RouteResult, RoutingProvider } from './routing-provider.js';

export interface RoutingGuardOptions {
  /** Appels autorisés par jour (palier gratuit) ; au-delà, estimation locale. */
  dailyQuota: number;
  maxEntries?: number;
  ttlMs?: number;
  now?: () => number;
  /** Événements sans donnée personnelle : quota à 80 %, quota atteint, panne. */
  onEvent?: (event: 'quota_warning' | 'quota_exceeded' | 'provider_error') => void;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Devant le fournisseur d'itinéraires (docs/couts.md) : cache mémoire LRU par coordonnées
 * arrondies (~100 m), compteur quotidien avec alerte à 80 % du quota, et repli sur
 * l'estimation locale en cas de panne ou de quota épuisé : un trajet a toujours un plan.
 */
export class GuardedRoutingProvider implements RoutingProvider {
  private readonly cache = new Map<string, { value: RouteResult; expiresAt: number }>();
  private day = -1;
  private calls = 0;

  constructor(
    private readonly primary: RoutingProvider,
    private readonly fallback: RoutingProvider,
    private readonly options: RoutingGuardOptions,
  ) {}

  async route(points: readonly LatLon[]): Promise<RouteResult> {
    const now = (this.options.now ?? Date.now)();
    const key = points.map((p) => `${p.lat.toFixed(3)},${p.lon.toFixed(3)}`).join(';');
    const hit = this.cache.get(key);
    if (hit && hit.expiresAt > now) {
      this.cache.delete(key);
      this.cache.set(key, hit);
      return hit.value;
    }

    const today = Math.floor(now / DAY_MS);
    if (today !== this.day) {
      this.day = today;
      this.calls = 0;
    }
    if (this.calls >= this.options.dailyQuota) {
      this.options.onEvent?.('quota_exceeded');
      return this.fallback.route(points);
    }
    this.calls++;
    if (this.calls === Math.ceil(this.options.dailyQuota * 0.8)) this.options.onEvent?.('quota_warning');

    let value: RouteResult;
    try {
      value = await this.primary.route(points);
    } catch {
      this.options.onEvent?.('provider_error');
      return this.fallback.route(points);
    }
    this.cache.set(key, { value, expiresAt: now + (this.options.ttlMs ?? 7 * DAY_MS) });
    if (this.cache.size > (this.options.maxEntries ?? 1000)) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) this.cache.delete(oldest);
    }
    return value;
  }
}
