import { AppError } from '../../shared/errors.js';
import { IdempotencyConflictError, type PaymentProvider } from '../../shared/payments/payment-provider.js';
import type { SettingsService } from '../settings/service.js';
import {
  chargeEntries,
  earningsReleaseEntries,
  holdEntries,
  isBalanced,
  isValidIban,
  normalizeIban,
  payoutEntries,
  payoutReversalEntries,
  releaseEntries,
  topupEntries,
  userAccount,
} from './domain.js';
import type { PaymentsRepo, Tx } from './repo.js';
import type { Entry } from './domain.js';

export interface WalletView {
  balanceCents: number;
  heldCents: number;
  /** Parts reçues, versées sur le solde après le délai de signalement. */
  pendingCents: number;
  history: { kind: string; amountCents: number; rideId: string | null; createdAt: Date }[];
}

export type ChargeOutcome = 'paid' | 'failed' | 'already';

/**
 * Portefeuille prépayé (cahier §5) : registre en écriture seule, opérations équilibrées et
 * idempotentes, en transaction. Les fonds sont chez le prestataire (`PaymentProvider`).
 */
export class WalletService {
  constructor(
    private readonly repo: PaymentsRepo,
    private readonly provider: PaymentProvider,
    private readonly settings: SettingsService,
  ) {}

  /** Verrou des portefeuilles (dans l'ordre des identifiants), à prendre avant toute opération. */
  lockWallets(userIds: readonly string[], tx: Tx): Promise<void> {
    return this.repo.lockWallets(userIds, tx);
  }

  async wallet(userId: string): Promise<WalletView> {
    return { ...(await this.repo.wallet(userId)), history: await this.repo.history(userId) };
  }

  /** Recharge (minimum `wallet.minTopupCents`) ; rejouée avec la même clé, sans doublon. */
  async topup(userId: string, amountCents: number, idempotencyKey: string): Promise<{ status: string; wallet: WalletView }> {
    const min = await this.settings.get('wallet.minTopupCents');
    if (amountCents < min) throw new AppError(400, 'topup_too_small', 'Montant de recharge trop faible');
    const key = `topup:${userId}:${idempotencyKey}`;
    const result = await this.provider.createTopup({ userId, amountCents, idempotencyKey: key }).catch((error: unknown) => {
      if (error instanceof IdempotencyConflictError) {
        throw new AppError(409, 'idempotency_conflict', 'Cette recharge a déjà été demandée avec un autre montant');
      }
      throw error;
    });
    await this.repo.transaction(async (tx) => {
      await this.repo.lockWallets([userId], tx);
      await this.repo.insertTopup(userId, amountCents, result.providerRef, result.status, tx);
      if (result.status === 'succeeded') await this.record(key, topupEntries(userId, amountCents), null, tx);
    });
    if (result.status === 'failed') throw new AppError(402, 'topup_failed', 'La recharge a été refusée');
    return { status: result.status, wallet: await this.wallet(userId) };
  }

  private async record(key: string, entries: Entry[], rideId: string | null, tx: Tx) {
    if (!isBalanced(entries)) throw new Error('Opération déséquilibrée');
    return this.repo.record(key, entries, rideId, tx);
  }

  /**
   * Départ du trajet : retient le prix maximal du passager (s'il était seul présent). Solde
   * insuffisant : rien n'est retenu et `false` est renvoyé (le passager ne voyage pas).
   */
  async holdForRide(
    input: { rideId: string; passengerId: string; driverId: string; maxCents: number },
    tx: Tx,
  ): Promise<boolean> {
    const { rideId, passengerId } = input;
    await this.repo.lockWallets([passengerId, input.driverId], tx);
    if (await this.repo.payment(rideId, passengerId, tx)) return true;
    if ((await this.repo.balance(userAccount(passengerId), tx)) < input.maxCents) return false;
    if (input.maxCents > 0) {
      await this.record(`ride:${rideId}:hold:${passengerId}`, holdEntries(passengerId, input.maxCents), rideId, tx);
    }
    await this.repo.upsertPayment(
      { rideId, payerId: passengerId, payeeId: input.driverId, shareCents: 0, commissionCents: 0, heldCents: input.maxCents, status: 'held' },
      tx,
    );
    return true;
  }

  /**
   * Clôture, passager arrivé : la retenue est libérée et il paie le prix final (part et
   * commission), jamais plus que ce qui a été retenu. Idempotent.
   */
  async chargeForRide(
    input: { rideId: string; passengerId: string; driverId: string; shareCents: number; commissionCents: number; now: Date },
    tx: Tx,
  ): Promise<ChargeOutcome> {
    const { rideId, passengerId, driverId } = input;
    await this.repo.lockWallets([passengerId, driverId], tx);
    const payment = await this.repo.payment(rideId, passengerId, tx);
    if (!payment || payment.status !== 'held') return 'already';
    // Jamais plus que la retenue (le prix maximal accepté) : commission d'abord, puis part.
    const commissionCents = Math.min(input.commissionCents, payment.held_cents);
    const shareCents = Math.min(input.shareCents, payment.held_cents - commissionCents);
    input = { ...input, shareCents, commissionCents };
    const available = (await this.repo.balance(userAccount(passengerId), tx)) + payment.held_cents;
    if (available < input.shareCents + input.commissionCents) {
      if (payment.held_cents > 0) {
        await this.record(`ride:${rideId}:release:${passengerId}`, releaseEntries(passengerId, payment.held_cents), rideId, tx);
      }
      await this.repo.setPaymentStatus(rideId, passengerId, 'failed', null, tx);
      return 'failed';
    }
    const entries = chargeEntries({
      passengerId,
      driverId,
      heldCents: payment.held_cents,
      shareCents: input.shareCents,
      commissionCents: input.commissionCents,
    });
    await this.record(`ride:${rideId}:charge:${passengerId}`, entries, rideId, tx);
    await this.repo.settlePayment({ rideId, payerId: passengerId, shareCents: input.shareCents, commissionCents: input.commissionCents, paidAt: input.now }, tx);
    return 'paid';
  }

  /**
   * Retrait vers le compte bancaire (cahier §5) : à partir de `wallet.minPayoutCents`, au plus
   * une fois tous les `wallet.payoutMinIntervalDays` jours. L'IBAN va au prestataire ; seuls ses
   * 4 derniers caractères sont gardés.
   */
  async payout(
    userId: string,
    input: { amountCents: number; iban: string; holderName: string },
    idempotencyKey: string,
    now: Date,
  ): Promise<WalletView> {
    const min = await this.settings.get('wallet.minPayoutCents');
    if (input.amountCents < min) throw new AppError(400, 'payout_too_small', 'Montant de retrait trop faible');
    const iban = normalizeIban(input.iban);
    if (!isValidIban(iban)) throw new AppError(400, 'iban_invalid', 'IBAN invalide');
    const key = `payout:${userId}:${idempotencyKey}`;
    if (await this.repo.operationExists(key)) return this.wallet(userId);
    const intervalDays = await this.settings.get('wallet.payoutMinIntervalDays');
    // Débit enregistré et validé avant l'appel au prestataire : un virement parti ne peut
    // jamais rester sans écriture (réponse perdue, transaction annulée), donc jamais doublé.
    const payoutId = await this.repo.transaction(async (tx) => {
      await this.repo.lockWallets([userId], tx);
      // Même clé en parallèle (double appui) : la seconde voit la première une fois le verrou pris.
      if (await this.repo.operationExists(key, tx)) return null;
      if ((await this.repo.balance(userAccount(userId), tx)) < input.amountCents) {
        throw new AppError(409, 'insufficient_funds', 'Solde insuffisant');
      }
      const last = await this.repo.lastPayoutAt(userId, tx);
      if (last && now.getTime() - last.getTime() < intervalDays * 86_400_000) {
        throw new AppError(429, 'payout_too_soon', 'Un retrait par semaine au plus');
      }
      const id = await this.repo.insertPayout({ userId, amountCents: input.amountCents, ibanLast4: iban.slice(-4) }, tx);
      await this.record(key, payoutEntries(userId, input.amountCents), null, tx);
      return id;
    });
    if (payoutId === null) return this.wallet(userId);
    let result: Awaited<ReturnType<PaymentProvider['createPayout']>>;
    try {
      result = await this.provider.createPayout({ userId, amountCents: input.amountCents, iban, holderName: input.holderName, idempotencyKey: key });
    } catch {
      // Issue inconnue : le retrait reste `pending`, débité ; l'équipe le rapproche (webhook en M4b).
      return this.wallet(userId);
    }
    await this.repo.transaction(async (tx) => {
      if (result.status === 'failed') {
        await this.repo.lockWallets([userId], tx);
        await this.repo.setPayoutResult(payoutId, 'failed', result.providerRef, tx);
        await this.record(`${key}:reversal`, payoutReversalEntries(userId, input.amountCents), null, tx);
      } else {
        await this.repo.setPayoutResult(payoutId, result.status === 'succeeded' ? 'paid' : 'pending', result.providerRef, tx);
      }
    });
    if (result.status === 'failed') throw new AppError(402, 'payout_failed', 'Le virement a été refusé');
    return this.wallet(userId);
  }

  /**
   * Délai de signalement passé (`wallet.releaseAfterHours`) : la part de chaque trajet payé
   * devient disponible pour le conducteur, sauf litige en attente d'arbitrage. Idempotent.
   */
  async releaseEarnings(now: Date): Promise<number> {
    const hours = await this.settings.get('wallet.releaseAfterHours');
    const due = await this.repo.releasablePayments(new Date(now.getTime() - hours * 3_600_000));
    let released = 0;
    for (const p of due) {
      await this.repo.transaction(async (tx) => {
        await this.repo.lockWallets([p.payeeId], tx);
        if (!(await this.repo.markReleased(p.rideId, p.payerId, now, tx))) return;
        if (p.shareCents > 0) {
          await this.record(`ride:${p.rideId}:earnings:${p.payerId}`, earningsReleaseEntries(p.payeeId, p.shareCents), p.rideId, tx);
        }
        released++;
      });
    }
    return released;
  }

  /** Clôture : les retenues des passagers absents sont libérées, sans paiement. */
  async releaseRemaining(rideId: string, tx: Tx): Promise<string[]> {
    const held = await this.repo.heldPayments(rideId, tx);
    await this.repo.lockWallets(held.map((h) => h.payerId), tx);
    for (const h of held) {
      if (h.heldCents > 0) {
        await this.record(`ride:${rideId}:release:${h.payerId}`, releaseEntries(h.payerId, h.heldCents), rideId, tx);
      }
      await this.repo.setPaymentStatus(rideId, h.payerId, 'refunded', null, tx);
    }
    return held.map((h) => h.payerId);
  }
}
