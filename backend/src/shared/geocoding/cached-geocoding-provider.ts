import type { GeocodedAddress, GeocodingProvider } from './geocoding-provider.js';

/**
 * Cache mémoire borné (LRU simple) devant un fournisseur : limite les appels externes
 * (docs/couts.md). Pas de persistance : les adresses sont des données personnelles.
 */
export class CachedGeocodingProvider implements GeocodingProvider {
  private readonly cache = new Map<string, { value: GeocodedAddress | null; expiresAt: number }>();

  constructor(
    private readonly inner: GeocodingProvider,
    private readonly maxEntries = 500,
    private readonly ttlMs = 24 * 60 * 60 * 1000,
    private readonly now: () => number = Date.now,
  ) {}

  async geocode(query: string): Promise<GeocodedAddress | null> {
    const key = query.trim().toLowerCase().replace(/\s+/g, ' ');
    const hit = this.cache.get(key);
    if (hit && hit.expiresAt > this.now()) {
      // Réinsère pour marquer l'entrée comme récemment utilisée.
      this.cache.delete(key);
      this.cache.set(key, hit);
      return hit.value;
    }
    const value = await this.inner.geocode(query);
    this.cache.delete(key);
    this.cache.set(key, { value, expiresAt: this.now() + this.ttlMs });
    if (this.cache.size > this.maxEntries) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) this.cache.delete(oldest);
    }
    return value;
  }
}
