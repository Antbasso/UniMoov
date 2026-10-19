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
 * Distance à bord de chaque arrêt intermédiaire (passagers dans l'ordre), mesurée depuis le
 * campus : à l'aller, de l'arrêt au campus (tronçons suivants) ; au retour, du campus à l'arrêt
 * (tronçons précédents). Sert au partage du prix au prorata (cahier §5).
 */
export function onboardDistances(direction: Direction, legs: readonly RouteLeg[]): number[] {
  const stops = Math.max(legs.length - 1, 0);
  const result: number[] = [];
  for (let i = 0; i < stops; i++) {
    const range = direction === 'to_campus' ? legs.slice(i + 1) : legs.slice(0, i + 1);
    result.push(Math.round(range.reduce((sum, leg) => sum + leg.distanceM, 0)));
  }
  return result;
}

/**
 * Clé des entrées d'un plan (départ, arrivée, passagers acceptés et leurs points) : un plan
 * calculé n'est enregistré que si ces entrées n'ont pas changé entre-temps.
 */
export function planKey(inputs: {
  start: LatLon;
  end: LatLon;
  stops: readonly { userId: string; point: LatLon }[];
}): string {
  const at = (p: LatLon) => `${p.lat.toFixed(6)},${p.lon.toFixed(6)}`;
  const stops = [...inputs.stops]
    .sort((a, b) => a.userId.localeCompare(b.userId))
    .map((s) => `${s.userId}@${at(s.point)}`);
  return [at(inputs.start), at(inputs.end), ...stops].join('|');
}

/** Écart à partir duquel une nouvelle heure de passage est signalée (en deçà : bruit d'itinéraire). */
export const PASSAGE_SHIFT_NOTICE_S = 60;

/**
 * Heures de passage qui bougent d'au moins `PASSAGE_SHIFT_NOTICE_S` entre l'ancien plan et le
 * nouveau (passager ajouté ou retiré). Seules les personnes déjà planifiées comptent : celle qui
 * vient d'être ajoutée découvre son heure sur le trajet.
 */
export function shiftedPassages(
  previous: ReadonlyMap<string, Date | null>,
  next: ReadonlyMap<string, Date>,
): { userId: string; eta: Date; earlier: boolean }[] {
  const shifted: { userId: string; eta: Date; earlier: boolean }[] = [];
  for (const [userId, eta] of next) {
    const before = previous.get(userId);
    if (!before) continue;
    const delta = eta.getTime() - before.getTime();
    if (Math.abs(delta) >= PASSAGE_SHIFT_NOTICE_S * 1000) shifted.push({ userId, eta, earlier: delta < 0 });
  }
  return shifted;
}

/**
 * Mon temps de trajet : tout l'itinéraire pour le conducteur ; pour un passager, de sa prise en
 * charge au campus (aller) ou du campus à sa dépose (retour). `stopIndex` : rang de mon arrêt
 * parmi les passagers ordonnés, -1 pour le conducteur.
 */
export function myDurationS(
  route: { durationS: number; legs: readonly { durationS: number }[] },
  stopIndex: number,
  direction: Direction,
): number {
  if (stopIndex < 0 || route.legs.length === 0) return route.durationS;
  const point = stopIndex + 1;
  const legs = direction === 'to_campus' ? route.legs.slice(point) : route.legs.slice(0, point);
  return legs.reduce((sum, leg) => sum + leg.durationS, 0);
}
