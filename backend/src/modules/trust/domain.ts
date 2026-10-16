/**
 * Confiance et fiabilité (cahier §7, §8, §10) : fonctions pures, sans base ni horloge.
 * Les poids et seuils viennent de `app_settings` (jamais en dur).
 */

export type ReliabilityKind = 'completed' | 'cancel_early' | 'cancel_medium' | 'cancel_late' | 'no_show' | 'correction';
export type CancelTier = 'early' | 'medium' | 'late';

export interface PenaltyParams {
  /** Annulation plus de `earlyHours` avant le trajet : pénalité légère. */
  earlyHours: number;
  /** Moins de `lateHours` avant (ou après l'heure) : pénalité forte. */
  lateHours: number;
  early: number;
  medium: number;
  late: number;
  noShow: number;
}

export interface ScoreParams {
  /** Score de départ, aussi le point vers lequel tire la moyenne quand il y a peu de trajets. */
  prior: number;
  /** Nombre de trajets « virtuels » au score de départ : aucun événement isolé ne fait chuter le score. */
  priorWeight: number;
  /** Part des notes dans le score, le reste venant du comportement. */
  ratingShare: number;
}

export interface ReliabilityEntry {
  kind: ReliabilityKind;
  weight: number;
}

/**
 * Pénalité dégressive selon le délai entre l'annulation et l'heure du trajet (cahier §8) :
 * plus elle est tardive, plus elle pèse.
 */
export function cancelTier(cancelledAt: Date, rideTime: Date, params: Pick<PenaltyParams, 'earlyHours' | 'lateHours'>): CancelTier {
  const hours = (rideTime.getTime() - cancelledAt.getTime()) / 3_600_000;
  if (hours >= params.earlyHours) return 'early';
  if (hours >= params.lateHours) return 'medium';
  return 'late';
}

export function cancelPenalty(tier: CancelTier, params: PenaltyParams): { kind: ReliabilityKind; weight: number } {
  return { kind: `cancel_${tier}`, weight: params[tier] };
}

const round3 = (x: number) => Math.round(x * 1000) / 1000;
const clamp01 = (x: number) => Math.min(1, Math.max(0, x));

/**
 * Score de fiabilité entre 0 et 1 (cahier §7).
 * - Comportement : trajets menés à bien face aux pénalités (annulations, absences), en
 *   moyenne bayésienne partant de `prior` : un nouvel inscrit n'est ni puni ni favorisé,
 *   un incident isolé pèse peu et le score remonte avec les trajets suivants.
 * - Notes : étoiles ramenées entre 0 et 1, même moyenne bayésienne.
 * Aucun seuil d'exclusion : le score ne sert qu'à classer (pas de sanction brutale).
 */
export function reliabilityScore(entries: readonly ReliabilityEntry[], stars: readonly number[], params: ScoreParams): number {
  let completed = 0;
  let penalties = 0;
  for (const e of entries) {
    if (e.kind === 'completed') completed += e.weight;
    else penalties += e.weight;
  }
  penalties = Math.max(0, penalties);
  const k = params.priorWeight;
  const behaviour = k + completed + penalties === 0 ? params.prior : (params.prior * k + completed) / (k + completed + penalties);
  const rated = stars.reduce((sum, s) => sum + (s - 1) / 4, 0);
  const rating = k + stars.length === 0 ? params.prior : (params.prior * k + rated) / (k + stars.length);
  return round3(clamp01((1 - params.ratingShare) * behaviour + params.ratingShare * rating));
}

/**
 * Coût de classement du matching (cahier §4) : détour réel plus un détour « fictif »
 * d'autant plus grand que le score est bas. Le seuil de détour du conducteur reste vérifié
 * sur le détour réel, jamais sur ce coût.
 */
export function rankingCost(detourSeconds: number, reliabilities: readonly number[], weightSeconds: number): number {
  return detourSeconds + reliabilities.reduce((sum, r) => sum + weightSeconds * (1 - clamp01(r)), 0);
}

export type DisputeReason = 'cancellation_penalty' | 'marked_absent' | 'payment' | 'driver_issue' | 'other';

/** Faits horodatés par le serveur, seuls utilisés par l'arbitrage automatique (cahier §10). */
export interface DisputeFacts {
  rideTime: Date;
  participant: {
    status: string;
    cancelledAt: Date | null;
    pickedUpAt: Date | null;
    presenceValidatedAt: Date | null;
  };
  /** Pénalités déjà appliquées à cette personne pour ce trajet (corrections comprises). */
  penalties: readonly ReliabilityEntry[];
}

export interface Arbitration {
  decision: 'upheld' | 'corrected' | 'escalated';
  /** Code d'explication, traduit côté mobile. */
  explanation:
    | 'penalty_matches_timestamps'
    | 'penalty_recomputed'
    | 'no_penalty'
    | 'presence_validated'
    | 'driver_confirmed_boarding'
    | 'no_presence_evidence'
    | 'not_absent'
    | 'needs_human';
  /** Correction à inscrire au score (poids négatif), le cas échéant. */
  correction: number;
}

const penaltyTotal = (entries: readonly ReliabilityEntry[], kinds: readonly ReliabilityKind[]) =>
  entries.filter((e) => kinds.includes(e.kind) || e.kind === 'correction').reduce((sum, e) => sum + e.weight, 0);

/**
 * Litige de niveau 1 : on ne tranche automatiquement que ce que les horodatages du serveur
 * établissent. Le reste passe à l'équipe (niveau 2).
 */
export function arbitrate(reason: DisputeReason, facts: DisputeFacts, params: PenaltyParams): Arbitration {
  const none = { correction: 0 };
  if (reason === 'cancellation_penalty') {
    const applied = penaltyTotal(facts.penalties, ['cancel_early', 'cancel_medium', 'cancel_late']);
    if (!facts.participant.cancelledAt || applied <= 0) return { decision: 'upheld', explanation: 'no_penalty', ...none };
    const expected = cancelPenalty(cancelTier(facts.participant.cancelledAt, facts.rideTime, params), params).weight;
    if (applied > expected + 1e-9) {
      return { decision: 'corrected', explanation: 'penalty_recomputed', correction: round3(expected - applied) };
    }
    return { decision: 'upheld', explanation: 'penalty_matches_timestamps', ...none };
  }
  if (reason === 'marked_absent') {
    const applied = penaltyTotal(facts.penalties, ['no_show']);
    if (facts.participant.status !== 'absent' && applied <= 0) return { decision: 'upheld', explanation: 'not_absent', ...none };
    if (facts.participant.presenceValidatedAt) {
      return { decision: 'corrected', explanation: 'presence_validated', correction: round3(-Math.max(0, applied)) };
    }
    // Le conducteur l'a déclaré à bord mais la proximité n'a pas été validée : déclarations
    // contradictoires, une personne de l'équipe tranche.
    if (facts.participant.pickedUpAt) return { decision: 'escalated', explanation: 'driver_confirmed_boarding', ...none };
    return { decision: 'upheld', explanation: 'no_presence_evidence', ...none };
  }
  return { decision: 'escalated', explanation: 'needs_human', ...none };
}
