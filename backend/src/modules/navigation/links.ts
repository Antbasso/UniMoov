import type { LatLon } from '../../shared/geo.js';

/**
 * Liens de navigation GPS (cahier §15, architecture §7) : fonctions pures. Les liens ne
 * contiennent que des coordonnées, jamais de nom ni d'information personnelle. Sans
 * origine, chaque application part de la position actuelle du téléphone.
 */
export type NavApp = 'google_maps' | 'apple_maps' | 'waze';

export const SUPPORTS_MULTI_STOP: Record<NavApp, boolean> = {
  google_maps: true,
  apple_maps: true,
  waze: false,
};

const coord = (p: LatLon) => `${p.lat.toFixed(6)},${p.lon.toFixed(6)}`;

function assertPoints(points: readonly LatLon[]): void {
  if (points.length === 0) throw new RangeError('Au moins une destination');
  for (const p of points) {
    if (!Number.isFinite(p.lat) || !Number.isFinite(p.lon) || Math.abs(p.lat) > 90 || Math.abs(p.lon) > 180) {
      throw new RangeError('Coordonnées invalides');
    }
  }
}

/** Google Maps : tous les arrêts restants en étapes, dans l'ordre, puis la destination. */
export function googleMapsLink(points: readonly LatLon[]): string {
  assertPoints(points);
  const destination = points.at(-1)!;
  const waypoints = points.slice(0, -1);
  const params = [
    'api=1',
    `destination=${coord(destination)}`,
    ...(waypoints.length > 0 ? [`waypoints=${waypoints.map(coord).join('%7C')}`] : []),
    'travelmode=driving',
  ];
  return `https://www.google.com/maps/dir/?${params.join('&')}`;
}

/** Apple Plans : destinations successives séparées par « to: ». */
export function appleMapsLink(points: readonly LatLon[]): string {
  assertPoints(points);
  return `https://maps.apple.com/?daddr=${points.map(coord).join('+to:')}&dirflg=d`;
}

/** Waze n'accepte qu'une destination : l'arrêt suivant seulement (navigation arrêt par arrêt). */
export function wazeLink(point: LatLon): string {
  assertPoints([point]);
  return `https://waze.com/ul?ll=${coord(point)}&navigate=yes`;
}

export function navigationLinks(remaining: readonly LatLon[]) {
  return {
    googleMaps: googleMapsLink(remaining),
    appleMaps: appleMapsLink(remaining),
    waze: { nextStop: wazeLink(remaining[0]!) },
  };
}
