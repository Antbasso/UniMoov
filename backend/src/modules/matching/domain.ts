import { distanceMeters, type LatLon } from '../../shared/geo.js';
import { rankingCost } from '../trust/domain.js';

/**
 * Matching v1 (cahier §3, §4 ; architecture §4) : fonctions pures, sans base ni réseau.
 * Détour estimé à vol d'oiseau × facteur routier (docs/couts.md) ; l'API d'itinéraires
 * n'est appelée qu'à la confirmation (M3).
 */
export type Direction = 'to_campus' | 'from_campus';
export type Role = 'driver' | 'passenger';
export type RoleMode = 'auto' | 'always_driver' | 'always_passenger';

export interface Need {
  userId: string;
  home: LatLon;
  /** Aller : début du premier cours. Retour : fin du dernier cours. */
  time: Date;
  roleMode: RoleMode;
  vehicle: { seats: number; maxDetourMinutes: number } | null;
  reliability: number;
}

export interface MatchParams {
  campus: LatLon;
  roadFactor: number;
  avgSpeedKmh: number;
  /** Écart maximal entre les horaires du conducteur et du passager. */
  arrivalWindowMinutes: number;
  /** Détour fictif ajouté au classement pour un score nul (cahier §4, §7). */
  reliabilityWeightSeconds: number;
}

export interface PlannedPassenger {
  userId: string;
  /** Détour ajouté par ce passager au trajet du conducteur. */
  detourSeconds: number;
}

export interface PlannedRide {
  driverId: string;
  passengers: PlannedPassenger[];
  totalDetourSeconds: number;
  seats: number;
  /** Aller : arrivée avant le premier cours de tous. Retour : départ après le dernier. */
  targetTime: Date;
}

const byId = (a: { userId: string }, b: { userId: string }) => a.userId.localeCompare(b.userId);

/**
 * Rôle de chacun pour un créneau (fonction `assignRole` de l'architecture §4).
 * Sans véhicule : passager. Mode forcé : respecté. Mode automatique : on fait conduire tant
 * que l'offre de places ne dépasse pas la demande (une marge est nécessaire, car le détour
 * limite qui peut monter avec qui), en commençant par les voitures les plus grandes.
 */
export function assignRoles(needs: readonly Need[]): Map<string, Role> {
  const roles = new Map<string, Role>();
  let seatsOffered = 0;
  let passengers = 0;
  const autos: Need[] = [];

  for (const need of needs) {
    if (!need.vehicle || need.roleMode === 'always_passenger') {
      roles.set(need.userId, 'passenger');
      passengers++;
    } else if (need.roleMode === 'always_driver') {
      roles.set(need.userId, 'driver');
      seatsOffered += need.vehicle.seats;
    } else {
      autos.push(need);
    }
  }

  autos.sort((a, b) => b.vehicle!.seats - a.vehicle!.seats || b.reliability - a.reliability || byId(a, b));
  for (const need of autos) {
    if (seatsOffered <= passengers) {
      roles.set(need.userId, 'driver');
      seatsOffered += need.vehicle!.seats;
    } else {
      roles.set(need.userId, 'passenger');
      passengers++;
    }
  }
  return roles;
}

/** Durée estimée d'un trajet passant par les points donnés, dans l'ordre. */
function routeSeconds(points: readonly LatLon[], params: MatchParams): number {
  let meters = 0;
  for (let i = 1; i < points.length; i++) meters += distanceMeters(points[i - 1]!, points[i]!);
  return (meters * params.roadFactor) / ((params.avgSpeedKmh * 1000) / 3600);
}

/** Ordre de ramassage : plus proche voisin depuis le domicile du conducteur. */
export function pickupOrder<T extends { home: LatLon }>(driverHome: LatLon, passengers: readonly T[]): T[] {
  const remaining = [...passengers];
  const ordered: T[] = [];
  let position = driverHome;
  while (remaining.length > 0) {
    let best = 0;
    for (let i = 1; i < remaining.length; i++) {
      if (distanceMeters(position, remaining[i]!.home) < distanceMeters(position, remaining[best]!.home)) best = i;
    }
    const [next] = remaining.splice(best, 1);
    ordered.push(next!);
    position = next!.home;
  }
  return ordered;
}

/**
 * Détour total (secondes) causé par des passagers. Le retour emprunte le même chemin en
 * sens inverse, le détour estimé est donc le même dans les deux sens.
 */
export function detourSeconds(driverHome: LatLon, passengerHomes: readonly LatLon[], params: MatchParams): number {
  const ordered = pickupOrder(
    driverHome,
    passengerHomes.map((home) => ({ home })),
  ).map((p) => p.home);
  const withPassengers = routeSeconds([driverHome, ...ordered, params.campus], params);
  const direct = routeSeconds([driverHome, params.campus], params);
  return Math.max(0, withPassengers - direct);
}

export function isTimeCompatible(driverTime: Date, passengerTime: Date, params: MatchParams): boolean {
  return Math.abs(driverTime.getTime() - passengerTime.getTime()) <= params.arrivalWindowMinutes * 60_000;
}

export interface Candidate {
  driver: Need;
  detourSeconds: number;
}

/**
 * Conducteurs possibles pour un passager (fonction `rankCandidates`) : horaire compatible,
 * détour sous le seuil du conducteur ; classés par détour combiné au score de fiabilité du
 * conducteur (`rankingCost`).
 */
export function rankCandidates(
  passenger: Need,
  drivers: readonly Need[],
  params: MatchParams,
  excluded: (driverId: string, passengerId: string) => boolean = () => false,
): Candidate[] {
  return drivers
    .filter((d) => d.vehicle && d.userId !== passenger.userId && !excluded(d.userId, passenger.userId))
    .filter((d) => isTimeCompatible(d.time, passenger.time, params))
    .map((driver) => ({ driver, detourSeconds: detourSeconds(driver.home, [passenger.home], params) }))
    .filter((c) => c.detourSeconds <= c.driver.vehicle!.maxDetourMinutes * 60)
    .map((c) => ({ c, cost: rankingCost(c.detourSeconds, [c.driver.reliability], params.reliabilityWeightSeconds) }))
    .sort((a, b) => a.cost - b.cost || b.c.driver.reliability - a.c.driver.reliability || byId(a.c.driver, b.c.driver))
    .map(({ c }) => c);
}

/**
 * Propositions d'un créneau (jour + sens), un trajet par conducteur. Conflit sur les places :
 * le plus court détour combiné aux scores de fiabilité du passager et du conducteur passe en
 * premier (cahier §4, §7). Chaque ajout est revérifié contre le seuil du conducteur avec
 * tous ses passagers (détour réel).
 */
export function matchSlot(
  needs: readonly Need[],
  direction: Direction,
  params: MatchParams,
  excluded: (driverId: string, passengerId: string) => boolean = () => false,
): { rides: PlannedRide[]; unmatched: string[] } {
  const roles = assignRoles(needs);
  const drivers = needs.filter((n) => roles.get(n.userId) === 'driver');
  const passengers = needs.filter((n) => roles.get(n.userId) === 'passenger');

  const pairs = passengers
    .flatMap((passenger) =>
      rankCandidates(passenger, drivers, params, excluded).map((c) => ({
        passenger,
        ...c,
        cost: rankingCost(c.detourSeconds, [passenger.reliability, c.driver.reliability], params.reliabilityWeightSeconds),
      })),
    )
    .sort(
      (a, b) =>
        a.cost - b.cost ||
        b.passenger.reliability - a.passenger.reliability ||
        byId(a.passenger, b.passenger) ||
        byId(a.driver, b.driver),
    );

  const assigned = new Map<string, Need[]>(drivers.map((d) => [d.userId, []]));
  const placed = new Set<string>();
  for (const { passenger, driver } of pairs) {
    if (placed.has(passenger.userId)) continue;
    const current = assigned.get(driver.userId)!;
    if (current.length >= driver.vehicle!.seats) continue;
    const total = detourSeconds(driver.home, [...current, passenger].map((p) => p.home), params);
    if (total > driver.vehicle!.maxDetourMinutes * 60) continue;
    current.push(passenger);
    placed.add(passenger.userId);
  }

  // Un trajet par conducteur, même sans passager : il sait qu'il conduit et sa voiture
  // reste visible pour « voir d'autres propositions » et la recherche manuelle.
  const rides: PlannedRide[] = [];
  for (const driver of drivers) {
    const riders = assigned.get(driver.userId)!;
    // Détour propre à chaque passager : coût marginal de l'ajouter aux autres.
    const total = detourSeconds(driver.home, riders.map((p) => p.home), params);
    const passengersPlanned = riders.map((p) => ({
      userId: p.userId,
      detourSeconds: Math.max(
        0,
        total - detourSeconds(driver.home, riders.filter((o) => o !== p).map((o) => o.home), params),
      ),
    }));
    const times = [driver, ...riders].map((n) => n.time.getTime());
    rides.push({
      driverId: driver.userId,
      passengers: passengersPlanned.sort(byId),
      totalDetourSeconds: total,
      seats: driver.vehicle!.seats,
      targetTime: new Date(direction === 'to_campus' ? Math.min(...times) : Math.max(...times)),
    });
  }

  return {
    rides: rides.sort((a, b) => a.driverId.localeCompare(b.driverId)),
    unmatched: passengers.filter((p) => !placed.has(p.userId)).map((p) => p.userId).sort(),
  };
}
