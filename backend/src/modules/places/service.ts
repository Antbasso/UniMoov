import { type Bbox, type MeetingSpot, type PlacesProvider, PlacesUnavailableError } from '../../shared/places/places-provider.js';

/**
 * Lieux où se retrouver, montrés sur la carte du point de rencontre : parkings publics et aires
 * de covoiturage (OpenStreetMap). Indisponibles : la carte reste utilisable sans eux.
 */
export class PlacesService {
  constructor(private readonly provider: PlacesProvider | null) {}

  async meetingSpots(bbox: Bbox): Promise<{ spots: MeetingSpot[]; available: boolean }> {
    if (!this.provider) return { spots: [], available: false };
    try {
      return { spots: await this.provider.meetingSpots(bbox), available: true };
    } catch (error) {
      if (error instanceof PlacesUnavailableError) return { spots: [], available: false };
      throw error;
    }
  }
}
