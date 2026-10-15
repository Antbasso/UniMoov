/** Géocodage d'adresses françaises, derrière une interface (docs/couts.md). */
export interface GeocodedAddress {
  label: string;
  lat: number;
  lon: number;
}

export interface GeocodingProvider {
  /** Meilleur résultat, ou `null` si l'adresse est introuvable ou trop incertaine. */
  geocode(query: string): Promise<GeocodedAddress | null>;
}

export class GeocodingUnavailableError extends Error {
  override readonly name = 'GeocodingUnavailableError';
}
