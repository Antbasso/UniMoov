/**
 * Gamification (décision de l'équipe du 18/10/2026) : points, niveaux, badges et impact,
 * calculés à partir des trajets réellement effectués. Fonctions pures, sans effet sur l'argent :
 * les récompenses sont symboliques (profil, classement du campus).
 */

/** Ce qu'une personne a fait (trajets terminés où elle était présente). */
export interface RideStats {
  /** Trajets terminés comme conducteur avec au moins un passager présent. */
  ridesDriven: number;
  /** Trajets terminés comme passager présent. */
  ridesAsPassenger: number;
  /** Passagers présents transportés (somme sur les trajets conduits). */
  passengersCarried: number;
  /** Notes de 5 étoiles reçues. */
  fiveStarRatings: number;
  /** Avis donnés aux personnes croisées (chaque note compte). */
  ratingsGiven?: number;
  /** Personnes différentes croisées sur des trajets terminés. */
  distinctCompanions: number;
  /** Kilomètres partagés : à bord pour un passager, kilomètres des passagers pour un conducteur. */
  sharedKm: number;
  /** Plus grand nombre de trajets terminés sur une même semaine. */
  bestWeekRides: number;
  /** Score de fiabilité (0 à 1). */
  reliability: number;
}

export const POINTS = { perRideDriven: 15, perPassengerCarried: 5, perRideAsPassenger: 10, perFiveStars: 3, perRatingGiven: 2 } as const;

export function pointsFor(
  s: Pick<RideStats, 'ridesDriven' | 'passengersCarried' | 'ridesAsPassenger' | 'fiveStarRatings' | 'ratingsGiven'>,
): number {
  return (
    s.ridesDriven * POINTS.perRideDriven +
    s.passengersCarried * POINTS.perPassengerCarried +
    s.ridesAsPassenger * POINTS.perRideAsPassenger +
    s.fiveStarRatings * POINTS.perFiveStars +
    (s.ratingsGiven ?? 0) * POINTS.perRatingGiven
  );
}

/** Niveaux, du premier au dernier, avec le minimum de points pour les atteindre. */
export const LEVELS = [
  { key: 'newcomer', min: 0 },
  { key: 'regular', min: 100 },
  { key: 'pillar', min: 300 },
  { key: 'super', min: 700 },
  { key: 'legend', min: 1500 },
] as const;

export type LevelKey = (typeof LEVELS)[number]['key'];

export function levelFor(points: number): { key: LevelKey; min: number; next: { key: LevelKey; min: number } | null } {
  let index = 0;
  for (let i = 0; i < LEVELS.length; i++) if (points >= LEVELS[i]!.min) index = i;
  const next = LEVELS[index + 1];
  return { key: LEVELS[index]!.key, min: LEVELS[index]!.min, next: next ? { key: next.key, min: next.min } : null };
}

/**
 * Émissions évitées : une voiture moyenne émet environ 193 g de CO₂ par km (ADEME, base
 * Carbone, voiture particulière). Chaque km partagé est un km qu'une personne n'a pas roulé seule.
 */
export const CO2_GRAMS_PER_KM = 193;

export function co2SavedKg(sharedKm: number): number {
  return Math.round((Math.max(0, sharedKm) * CO2_GRAMS_PER_KM) / 1000);
}

/** Badges : un objectif chiffré chacun, la progression est montrée tant qu'il n'est pas atteint. */
export const BADGES = [
  { key: 'first_ride', goal: 1, value: (s: RideStats) => s.ridesDriven + s.ridesAsPassenger },
  { key: 'ten_rides', goal: 10, value: (s: RideStats) => s.ridesDriven + s.ridesAsPassenger },
  { key: 'fifty_rides', goal: 50, value: (s: RideStats) => s.ridesDriven + s.ridesAsPassenger },
  { key: 'loyal_driver', goal: 10, value: (s: RideStats) => s.ridesDriven },
  { key: 'full_week', goal: 5, value: (s: RideStats) => s.bestWeekRides },
  { key: 'sociable', goal: 10, value: (s: RideStats) => s.distinctCompanions },
  { key: 'eco', goal: 100, value: (s: RideStats) => co2SavedKg(s.sharedKm) },
  // Fiable : 5 trajets au moins et un score d'au moins 95 % (en pour cent pour rester entier).
  {
    key: 'reliable',
    goal: 5,
    value: (s: RideStats) => (s.reliability >= 0.95 ? s.ridesDriven + s.ridesAsPassenger : 0),
  },
] as const;

export type BadgeKey = (typeof BADGES)[number]['key'];

export function badgesFor(s: RideStats): { key: BadgeKey; goal: number; progress: number; earned: boolean }[] {
  return BADGES.map((b) => {
    const value = Math.max(0, Math.floor(b.value(s)));
    return { key: b.key, goal: b.goal, progress: Math.min(value, b.goal), earned: value >= b.goal };
  });
}

/** Classement : points décroissants, égalité départagée par l'identifiant (ordre stable). */
export function rank<T extends { userId: string; points: number }>(entries: readonly T[]): (T & { rank: number })[] {
  const sorted = [...entries].sort((a, b) => b.points - a.points || a.userId.localeCompare(b.userId));
  let previous: number | null = null;
  let current = 0;
  return sorted.map((e, i) => {
    if (e.points !== previous) current = i + 1;
    previous = e.points;
    return { ...e, rank: current };
  });
}
