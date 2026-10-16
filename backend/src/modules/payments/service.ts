import { AppError } from '../../shared/errors.js';
import type { PaymentProvider } from '../../shared/payments/payment-provider.js';
import type { SettingsService } from '../settings/service.js';
import { chargeEntries, holdAmount, holdEntries, isBalanced, releaseEntries, topupEntries, userAccount } from './domain.js';
import type { PaymentsRepo, Tx } from './repo.js';

export interface WalletView {
  balanceCents: number;
  heldCents: number;
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

  async wallet(userId: string): Promise<WalletView> {
    return { ...(await this.repo.wallet(userId)), history: await this.repo.history(userId) };
  }

  /** Recharge (minimum `wallet.minTopupCents`) ; rejouée avec la même clé, sans doublon. */
  async topup(userId: string, amountCents: number, idempotencyKey: string): Promise<{ status: string; wallet: WalletView }> {
    const min = await this.settings.get('wallet.minTopupCents');
    if (amountCents < min) throw new AppError(400, 'topup_too_small', 'Montant de recharge trop faible');
    const key = `topup:${userId}:${idempotencyKey}`;
    const result = await this.provider.createTopup({ userId, amountCents, idempotencyKey: key });
    await this.repo.transaction(async (tx) => {
      await this.repo.lockWallets([userId], tx);
      await this.repo.insertTopup(userId, amountCents, result.providerRef, result.status, tx);
      if (result.status === 'succeeded') await this.record(key, topupEntries(userId, amountCents), null, tx);
    });
    if (result.status === 'failed') throw new AppError(402, 'topup_failed', 'La recharge a été refusée');
    return { status: result.status, wallet: await this.wallet(userId) };
  }

  private async record(key: string, entries: ReturnType<typeof topupEntries>, rideId: string | null, tx: Tx) {
    if (!isBalanced(entries)) throw new Error('Opération déséquilibrée');
    return this.repo.record(key, entries, rideId, tx);
  }

  /**
   * Départ du trajet : retient le prix estimé plus la marge (ce qui est disponible, au plus).
   * Le paiement réel a lieu à la validation de présence.
   */
  async holdForRide(
    input: { rideId: string; passengerId: string; driverId: string; shareCents: number; commissionCents: number },
    tx: Tx,
  ): Promise<number> {
    const { rideId, passengerId } = input;
    await this.repo.lockWallets([passengerId, input.driverId], tx);
    if (await this.repo.payment(rideId, passengerId, tx)) return 0;
    const margin = await this.settings.get('wallet.holdMarginPercent');
    const wanted = holdAmount(input.shareCents + input.commissionCents, margin);
    const held = Math.min(wanted, Math.max(0, await this.repo.balance(userAccount(passengerId), tx)));
    if (held > 0) await this.record(`ride:${rideId}:hold:${passengerId}`, holdEntries(passengerId, held), rideId, tx);
    await this.repo.upsertPayment({ ...input, payerId: passengerId, payeeId: input.driverId, heldCents: held, status: 'held' }, tx);
    return held;
  }

  /**
   * Présence validée : la retenue est libérée et le passager paie sa part et la commission,
   * si son solde le permet (jamais de solde négatif). Idempotent.
   */
  async chargeForRide(input: { rideId: string; passengerId: string; driverId: string; now: Date }, tx: Tx): Promise<ChargeOutcome> {
    const { rideId, passengerId, driverId } = input;
    await this.repo.lockWallets([passengerId, driverId], tx);
    const payment = await this.repo.payment(rideId, passengerId, tx);
    if (!payment || payment.status !== 'held') return 'already';
    const available = (await this.repo.balance(userAccount(passengerId), tx)) + payment.held_cents;
    const total = payment.share_cents + payment.commission_cents;
    if (available < total) {
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
      shareCents: payment.share_cents,
      commissionCents: payment.commission_cents,
    });
    await this.record(`ride:${rideId}:charge:${passengerId}`, entries, rideId, tx);
    await this.repo.setPaymentStatus(rideId, passengerId, 'paid', input.now, tx);
    return 'paid';
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
