/** Lieux publics où se retrouver : parkings ouverts au public et aires de covoiturage. */
export interface MeetingSpot {
  kind: 'parking' | 'carpool';
  name: string | null;
  lat: number;
  lon: number;
}

export interface Bbox {
  south: number;
  west: number;
  north: number;
  east: number;
}

/** Lieux de rendez-vous d'une zone, derrière une interface (docs/couts.md). */
export interface PlacesProvider {
  meetingSpots(bbox: Bbox): Promise<MeetingSpot[]>;
}

export class PlacesUnavailableError extends Error {
  override readonly name = 'PlacesUnavailableError';
}

export const inBbox = (b: Bbox, p: { lat: number; lon: number }) =>
  p.lat >= b.south && p.lat <= b.north && p.lon >= b.west && p.lon <= b.east;
