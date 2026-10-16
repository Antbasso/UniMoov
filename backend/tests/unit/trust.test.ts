import { describe, expect, it } from 'vitest';
import {
  arbitrate,
  cancelPenalty,
  cancelTier,
  type DisputeFacts,
  type PenaltyParams,
  rankingCost,
  reliabilityScore,
  type ScoreParams,
} from '../../src/modules/trust/domain.js';

const penalties: PenaltyParams = { earlyHours: 24, lateHours: 2, early: 0.25, medium: 0.5, late: 1, noShow: 1.5 };
const score: ScoreParams = { prior: 0.8, priorWeight: 5, ratingShare: 0.4 };
const ride = new Date('2026-10-20T07:30:00Z');
const hoursBefore = (h: number) => new Date(ride.getTime() - h * 3_600_000);
const completed = (n: number) => Array.from({ length: n }, () => ({ kind: 'completed' as const, weight: 1 }));

describe('cancelTier : pénalité dégressive selon le délai', () => {
  it('précoce, moyenne, tardive, bornes comprises', () => {
    expect(cancelTier(hoursBefore(48), ride, penalties)).toBe('early');
    expect(cancelTier(hoursBefore(24), ride, penalties)).toBe('early');
    expect(cancelTier(hoursBefore(23.9), ride, penalties)).toBe('medium');
    expect(cancelTier(hoursBefore(2), ride, penalties)).toBe('medium');
    expect(cancelTier(hoursBefore(1.9), ride, penalties)).toBe('late');
  });

  it('après l’heure du trajet : tardive', () => {
    expect(cancelTier(hoursBefore(-1), ride, penalties)).toBe('late');
  });

  it('plus tardive, plus lourde', () => {
    const early = cancelPenalty('early', penalties);
    const medium = cancelPenalty('medium', penalties);
    const late = cancelPenalty('late', penalties);
    expect(early).toEqual({ kind: 'cancel_early', weight: 0.25 });
    expect(early.weight).toBeLessThan(medium.weight);
    expect(medium.weight).toBeLessThan(late.weight);
    expect(late.weight).toBeLessThan(penalties.noShow);
  });
});

describe('reliabilityScore', () => {
  it('nouvel inscrit : score de départ', () => {
    expect(reliabilityScore([], [], score)).toBe(0.8);
  });

  it('cas limites : aucun poids de départ, notes seules', () => {
    expect(reliabilityScore([], [], { ...score, priorWeight: 0 })).toBe(0.8);
    expect(reliabilityScore([], [5, 5], { ...score, priorWeight: 0, ratingShare: 1 })).toBe(1);
    expect(reliabilityScore([], [1], { ...score, priorWeight: 0, ratingShare: 1 })).toBe(0);
  });

  it('une annulation tardive pèse plus qu’une précoce, une absence plus encore', () => {
    const base = completed(5);
    const early = reliabilityScore([...base, { kind: 'cancel_early', weight: 0.25 }], [], score);
    const late = reliabilityScore([...base, { kind: 'cancel_late', weight: 1 }], [], score);
    const noShow = reliabilityScore([...base, { kind: 'no_show', weight: 1.5 }], [], score);
    expect(early).toBeGreaterThan(late);
    expect(late).toBeGreaterThan(noShow);
  });

  it('pas de sanction brutale : un incident isolé garde un score correct', () => {
    expect(reliabilityScore([{ kind: 'no_show', weight: 1.5 }], [], score)).toBeGreaterThan(0.6);
  });

  it('le score remonte avec les trajets menés à bien', () => {
    const incident = [{ kind: 'cancel_late' as const, weight: 1 }];
    const after = reliabilityScore([...incident, ...completed(10)], [], score);
    expect(after).toBeGreaterThan(reliabilityScore(incident, [], score));
    expect(after).toBeGreaterThan(0.8);
  });

  it('les notes comptent selon leur part', () => {
    const good = reliabilityScore(completed(3), [5, 5, 5], score);
    const bad = reliabilityScore(completed(3), [1, 1, 1], score);
    expect(good).toBeGreaterThan(bad);
    expect(reliabilityScore(completed(3), [1, 1, 1], { ...score, ratingShare: 0 })).toBe(
      reliabilityScore(completed(3), [5, 5, 5], { ...score, ratingShare: 0 }),
    );
  });

  it('une correction annule la pénalité', () => {
    const corrected = reliabilityScore(
      [...completed(2), { kind: 'no_show', weight: 1.5 }, { kind: 'correction', weight: -1.5 }],
      [],
      score,
    );
    expect(corrected).toBe(reliabilityScore(completed(2), [], score));
  });

  it('borné entre 0 et 1, trois décimales', () => {
    const many = Array.from({ length: 200 }, () => ({ kind: 'no_show' as const, weight: 1.5 }));
    const low = reliabilityScore(many, [1, 1, 1], score);
    expect(low).toBeGreaterThanOrEqual(0);
    expect(reliabilityScore(completed(500), Array(100).fill(5), score)).toBeLessThanOrEqual(1);
    expect(Number.isInteger(low * 1000)).toBe(true);
    // Corrections plus fortes que les pénalités : jamais de bonus.
    expect(reliabilityScore([{ kind: 'correction', weight: -3 }], [], score)).toBe(0.8);
  });
});

describe('rankingCost', () => {
  it('score parfait : détour réel ; score bas : détour majoré', () => {
    expect(rankingCost(120, [1], 300)).toBe(120);
    expect(rankingCost(120, [0.5], 300)).toBe(270);
    expect(rankingCost(120, [0.5, 0.5], 300)).toBe(420);
    expect(rankingCost(120, [0], 0)).toBe(120);
  });

  it('valeurs hors bornes ramenées entre 0 et 1', () => {
    expect(rankingCost(0, [1.2], 300)).toBe(0);
    expect(rankingCost(0, [-1], 300)).toBe(300);
  });
});

describe('arbitrate : litige de niveau 1 sur les horodatages serveur', () => {
  const facts = (overrides: Partial<DisputeFacts['participant']>, applied: DisputeFacts['penalties'] = []): DisputeFacts => ({
    rideTime: ride,
    participant: { status: 'cancelled', cancelledAt: null, pickedUpAt: null, presenceValidatedAt: null, ...overrides },
    penalties: applied,
  });

  it('pénalité d’annulation conforme aux horodatages : maintenue', () => {
    const result = arbitrate('cancellation_penalty', facts({ cancelledAt: hoursBefore(1) }, [{ kind: 'cancel_late', weight: 1 }]), penalties);
    expect(result).toEqual({ decision: 'upheld', explanation: 'penalty_matches_timestamps', correction: 0 });
  });

  it('pénalité plus lourde que ce que disent les horodatages (réglage modifié) : corrigée', () => {
    const result = arbitrate('cancellation_penalty', facts({ cancelledAt: hoursBefore(30) }, [{ kind: 'cancel_late', weight: 1 }]), penalties);
    expect(result).toEqual({ decision: 'corrected', explanation: 'penalty_recomputed', correction: -0.75 });
  });

  it('pénalité déjà corrigée : plus rien à corriger', () => {
    const applied = [
      { kind: 'cancel_late' as const, weight: 1 },
      { kind: 'correction' as const, weight: -0.75 },
    ];
    expect(arbitrate('cancellation_penalty', facts({ cancelledAt: hoursBefore(30) }, applied), penalties).decision).toBe('upheld');
  });

  it('aucune pénalité : rien à contester', () => {
    expect(arbitrate('cancellation_penalty', facts({}), penalties).explanation).toBe('no_penalty');
  });

  it('absent sans validation ni montée déclarée : maintenu (cahier §9)', () => {
    const result = arbitrate('marked_absent', facts({ status: 'absent' }, [{ kind: 'no_show', weight: 1.5 }]), penalties);
    expect(result).toEqual({ decision: 'upheld', explanation: 'no_presence_evidence', correction: 0 });
  });

  it('absent mais présence validée par le serveur : pénalité retirée', () => {
    const result = arbitrate(
      'marked_absent',
      facts({ status: 'absent', presenceValidatedAt: hoursBefore(0) }, [{ kind: 'no_show', weight: 1.5 }]),
      penalties,
    );
    expect(result).toEqual({ decision: 'corrected', explanation: 'presence_validated', correction: -1.5 });
  });

  it('déclaré monté par le conducteur sans validation GPS : transmis à l’équipe', () => {
    const result = arbitrate(
      'marked_absent',
      facts({ status: 'absent', pickedUpAt: hoursBefore(0.2) }, [{ kind: 'no_show', weight: 1.5 }]),
      penalties,
    );
    expect(result.decision).toBe('escalated');
    expect(result.explanation).toBe('driver_confirmed_boarding');
  });

  it('pas absent : rien à contester', () => {
    expect(arbitrate('marked_absent', facts({ status: 'accepted' }), penalties).explanation).toBe('not_absent');
  });

  it('paiement, conducteur, autre : arbitrage humain', () => {
    for (const reason of ['payment', 'driver_issue', 'other'] as const) {
      expect(arbitrate(reason, facts({}), penalties)).toEqual({ decision: 'escalated', explanation: 'needs_human', correction: 0 });
    }
  });
});
