import { describe, expect, it } from 'vitest';
import {
  chargeEntries,
  CLEARING,
  COMMISSION,
  heldAccount,
  holdAmount,
  holdEntries,
  isBalanced,
  payoutEntries,
  releaseEntries,
  topupEntries,
  userAccount,
} from '../../src/modules/payments/domain.js';

const sumFor = (entries: { account: string; amountCents: number }[], account: string) =>
  entries.filter((e) => e.account === account).reduce((s, e) => s + e.amountCents, 0);

describe('opérations du registre', () => {
  it('chaque opération est équilibrée (somme nulle)', () => {
    for (const op of [
      topupEntries('p', 1000),
      holdEntries('p', 300),
      releaseEntries('p', 300),
      payoutEntries('d', 1500),
      chargeEntries({ passengerId: 'p', driverId: 'd', heldCents: 110, shareCents: 72, commissionCents: 20 }),
    ]) {
      expect(isBalanced(op)).toBe(true);
    }
  });

  it('paiement : la retenue revient au passager, qui paie part + commission ; le conducteur reçoit la part', () => {
    const op = chargeEntries({ passengerId: 'p', driverId: 'd', heldCents: 110, shareCents: 72, commissionCents: 20 });
    expect(sumFor(op, heldAccount('p'))).toBe(-110);
    expect(sumFor(op, userAccount('p'))).toBe(110 - 92);
    expect(sumFor(op, userAccount('d'))).toBe(72);
    expect(sumFor(op, COMMISSION)).toBe(20);
  });

  it('un parcours complet (recharge, retenue, paiement, retrait) reste équilibré au global', () => {
    const all = [
      ...topupEntries('p', 1000),
      ...holdEntries('p', 110),
      ...chargeEntries({ passengerId: 'p', driverId: 'd', heldCents: 110, shareCents: 72, commissionCents: 20 }),
      ...topupEntries('d', 1000),
      ...payoutEntries('d', 1072),
    ];
    expect(isBalanced(all)).toBe(true);
    expect(sumFor(all, userAccount('p'))).toBe(1000 - 92);
    expect(sumFor(all, heldAccount('p'))).toBe(0);
    expect(sumFor(all, userAccount('d'))).toBe(0);
    expect(sumFor(all, CLEARING)).toBe(-1000 - 1000 + 1072);
  });

  it('cas limites : sans retenue, part nulle, montants invalides', () => {
    const noHold = chargeEntries({ passengerId: 'p', driverId: 'd', heldCents: 0, shareCents: 50, commissionCents: 0 });
    expect(noHold.map((e) => e.kind)).toEqual(['ride_charge', 'ride_credit']);
    expect(chargeEntries({ passengerId: 'p', driverId: 'd', heldCents: 0, shareCents: 0, commissionCents: 0 })).toEqual([]);
    expect(() => topupEntries('p', 0)).toThrow(RangeError);
    expect(() => holdEntries('p', 1.5)).toThrow(RangeError);
    expect(() => chargeEntries({ passengerId: 'p', driverId: 'p', heldCents: 0, shareCents: 1, commissionCents: 0 })).toThrow(RangeError);
    expect(() => chargeEntries({ passengerId: 'p', driverId: 'd', heldCents: 0, shareCents: -1, commissionCents: 0 })).toThrow(RangeError);
  });
});

describe('holdAmount', () => {
  it('prix estimé majoré de la marge, au centime supérieur', () => {
    expect(holdAmount(92, 20)).toBe(111); // 110,4 → 111
    expect(holdAmount(100, 0)).toBe(100);
    expect(holdAmount(0, 20)).toBe(0);
    expect(() => holdAmount(-1, 20)).toThrow(RangeError);
    expect(() => holdAmount(10, -5)).toThrow(RangeError);
  });
});
