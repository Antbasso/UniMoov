import { type Bbox, inBbox, type MeetingSpot, type PlacesProvider } from './places-provider.js';

/** Pas de la grille (en degrés, environ 2 km) : des zones voisines partagent la même requête. */
const GRID = 0.02;

const snap = (b: Bbox): Bbox => ({
  south: Math.floor(b.south / GRID) * GRID,
  west: Math.floor(b.west / GRID) * GRID,
  north: Math.ceil(b.north / GRID) * GRID,
  east: Math.ceil(b.east / GRID) * GRID,
});

/**
 * Cache mémoire borné devant le fournisseur de lieux (docs/couts.md) : la zone demandée est
 * arrondie à une grille, puis gardée une semaine (les parkings changent rarement). Données
 * publiques, sans rien de personnel.
 */
export class CachedPlacesProvider implements PlacesProvider {
  private readonly cache = new Map<string, { value: MeetingSpot[]; expiresAt: number }>();

  constructor(
    private readonly inner: PlacesProvider,
    private readonly maxEntries = 200,
    private readonly ttlMs = 7 * 24 * 60 * 60 * 1000,
    private readonly now: () => number = Date.now,
  ) {}

  async meetingSpots(bbox: Bbox): Promise<MeetingSpot[]> {
    const zone = snap(bbox);
    const key = [zone.south, zone.west, zone.north, zone.east].map((v) => v.toFixed(2)).join(',');
    let hit = this.cache.get(key);
    if (!hit || hit.expiresAt <= this.now()) {
      hit = { value: await this.inner.meetingSpots(zone), expiresAt: this.now() + this.ttlMs };
    }
    // Réinsérée : récemment utilisée.
    this.cache.delete(key);
    this.cache.set(key, hit);
    if (this.cache.size > this.maxEntries) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) this.cache.delete(oldest);
    }
    return hit.value.filter((spot) => inBbox(bbox, spot));
  }
}
