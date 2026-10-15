import { distanceMeters, type LatLon } from '../../shared/geo.js';
import type { RouteLeg } from '../../shared/routing/routing-provider.js';

/**
 * Plan d'un trajet confirmé (cahier §14, architecture §5) : fonctions pures.
 * Aller : domicile du conducteur → arrêts → campus, arrivée à l'heure cible.
 * Retour : campus → arrêts → domicile du conducteur, départ à l'heure cible.
 */
export type Direction = 'to_campus' | 'from_campus';

const EXACT_LIMIT = 7;

function pathLength(points: readonly LatLon[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) total += distanceMeters(points[i - 1]!, points[i]!);
  return total;
}

function* permutations<T>(items: readonly T[]): Generator<T[]> {
  if (items.length <= 1) {
    yield [...items];
    return;
  }
  for (let i = 0; i < items.length; i++) {
    const rest = [...items.slice(0, i), ...items.slice(i + 1)];
    for (const perm of permutations(rest)) yield [items[i]!, ...perm];
  }
}

/**
 * Ordre des arrêts minimisant la distance entre un départ et une arrivée fixes. Exact
 * jusqu'à 7 arrêts (une voiture en a au plus 8 places), plus proche voisin au-delà.
 * Égalité : l'ordre d'entrée est conservé (résultat déterministe).
 */
export function orderStops<T extends { point: LatLon }>(start: LatLon, end: LatLon, stops: readonly T[]): T[] {
  if (stops.length <= EXACT_LIMIT) {
    let best: T[] = [...stops];
    let bestLength = pathLength([start, ...best.map((s) => s.point), end]);
    for (const perm of permutations(stops)) {
      const length = pathLength([start, ...perm.map((s) => s.point), end]);
      if (length < bestLength - 1e-6) {
        best = perm;
        bestLength = length;
      }
    }
    return best;
  }
  const remaining = [...stops];
  const ordered: T[] = [];
  let position = start;
  while (remaining.length > 0) {
    let best = 0;
    for (let i = 1; i < remaining.length; i++) {
      if (distanceMeters(position, remaining[i]!.point) < distanceMeters(position, remaining[best]!.point)) best = i;
    }
    const [next] = remaining.splice(best, 1);
    ordered.push(next!);
    position = next!.point;
  }
  return ordered;
}

/**
 * Heure de passage à chaque point (départ, arrêts, arrivée) à partir des durées des
 * tronçons. Aller : on part assez tôt pour arriver à l'heure cible. Retour : on part à
 * l'heure cible.
 */
export function passageTimes(direction: Direction, targetTime: Date, legs: readonly RouteLeg[]): Date[] {
  const total = legs.reduce((sum, leg) => sum + leg.durationS, 0);
  let t = targetTime.getTime() - (direction === 'to_campus' ? total * 1000 : 0);
  const times = [new Date(t)];
  for (const leg of legs) {
    t += leg.durationS * 1000;
    times.push(new Date(t));
  }
  return times;
}

/**
 * Clé des entrées d'un plan (passagers acceptés et points de prise en charge) : un plan
 * calculé n'est enregistré que si ces entrées n'ont pas changé entre-temps.
 */
export function planKey(stops: readonly { userId: string; point: LatLon }[]): string {
  return [...stops]
    .sort((a, b) => a.userId.localeCompare(b.userId))
    .map((s) => `${s.userId}@${s.point.lat.toFixed(6)},${s.point.lon.toFixed(6)}`)
    .join('|');
}
