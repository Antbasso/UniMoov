/**
 * Prestataire de paiement agréé, derrière une interface (docs/couts.md) : UniMoov ne tient
 * pas les fonds et ne voit jamais de numéro de carte.
 */
export type ProviderStatus = 'succeeded' | 'pending' | 'failed';

export interface PaymentProvider {
  /** Recharge du portefeuille ; la clé d'idempotence rend l'appel rejouable sans doublon. */
  createTopup(input: { userId: string; amountCents: number; idempotencyKey: string }): Promise<{
    providerRef: string;
    status: ProviderStatus;
  }>;
  /** Virement du solde d'un conducteur vers son compte bancaire. */
  createPayout(input: { userId: string; amountCents: number; idempotencyKey: string }): Promise<{
    providerRef: string;
    status: ProviderStatus;
  }>;
}

/**
 * Fournisseur factice complet (AGENTS.md) : recharge, retrait, échec à la demande. Aucun
 * appel réseau ; le même appel (même clé) renvoie le même résultat.
 */
export class FakePaymentProvider implements PaymentProvider {
  private readonly results = new Map<string, { providerRef: string; status: ProviderStatus }>();
  /** Montants refusés (simulation d'échec). */
  readonly failingAmounts = new Set<number>();
  calls = 0;

  private run(prefix: string, amountCents: number, key: string) {
    this.calls++;
    const known = this.results.get(key);
    if (known) return Promise.resolve(known);
    const result = {
      providerRef: `fake_${prefix}_${this.results.size + 1}`,
      status: (this.failingAmounts.has(amountCents) ? 'failed' : 'succeeded') as ProviderStatus,
    };
    this.results.set(key, result);
    return Promise.resolve(result);
  }

  createTopup(input: { userId: string; amountCents: number; idempotencyKey: string }) {
    return this.run('topup', input.amountCents, input.idempotencyKey);
  }

  createPayout(input: { userId: string; amountCents: number; idempotencyKey: string }) {
    return this.run('payout', input.amountCents, input.idempotencyKey);
  }
}
