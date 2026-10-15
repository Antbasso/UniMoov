/**
 * Secteur approximatif d'un point : cellule d'une grille d'environ 500 m (docs/architecture.md §5).
 * Seul le centre de la cellule est montré avant acceptation mutuelle, jamais le point exact.
 */
export const SECTOR_SIZE_M = 500;
const METERS_PER_DEGREE_LAT = 111_320;
const LAT_STEP = SECTOR_SIZE_M / METERS_PER_DEGREE_LAT;
const MAX_ABS_LAT = 85;

export interface LatLon {
  lat: number;
  lon: number;
}

function lonStepForRow(row: number): number {
  const rowCenterLat = (row + 0.5) * LAT_STEP;
  return SECTOR_SIZE_M / (METERS_PER_DEGREE_LAT * Math.cos((rowCenterLat * Math.PI) / 180));
}

function assertValid({ lat, lon }: LatLon): void {
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > MAX_ABS_LAT || Math.abs(lon) > 180) {
    throw new RangeError('Coordonnées hors limites');
  }
}

/** Identifiant de secteur `"<ligne>:<colonne>"`. */
export function sectorOf(point: LatLon): string {
  assertValid(point);
  const row = Math.floor(point.lat / LAT_STEP);
  const col = Math.floor(point.lon / lonStepForRow(row));
  return `${row}:${col}`;
}

/** Centre du secteur, seule position exposée avant acceptation mutuelle. */
export function sectorCenter(sector: string): LatLon {
  const match = /^(-?\d+):(-?\d+)$/.exec(sector);
  if (!match) throw new RangeError('Secteur invalide');
  const row = Number(match[1]);
  const col = Number(match[2]);
  return { lat: (row + 0.5) * LAT_STEP, lon: (col + 0.5) * lonStepForRow(row) };
}

/** Distance orthodromique en mètres (formule de haversine). */
export function distanceMeters(a: LatLon, b: LatLon): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(h));
}
