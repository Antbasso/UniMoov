import { type Bbox, inBbox, type MeetingSpot, type PlacesProvider } from './places-provider.js';

/** Quelques lieux d'Annecy, sans appel externe (développement et tests). */
export class FakePlacesProvider implements PlacesProvider {
  calls = 0;

  constructor(
    private readonly spots: MeetingSpot[] = [
      { kind: 'parking', name: 'Parking des Marquisats', lat: 45.8952, lon: 6.1365 },
      { kind: 'parking', name: 'Parking Bonlieu', lat: 45.9007, lon: 6.1291 },
      { kind: 'carpool', name: 'Aire de covoiturage de Seynod', lat: 45.8848, lon: 6.0921 },
      { kind: 'carpool', name: null, lat: 45.9302, lon: 6.1015 },
    ],
  ) {}

  meetingSpots(bbox: Bbox): Promise<MeetingSpot[]> {
    this.calls++;
    return Promise.resolve(this.spots.filter((spot) => inBbox(bbox, spot)));
  }
}
