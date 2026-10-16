import { randomUUID } from 'node:crypto';
import { sql } from 'drizzle-orm';
import type { Db } from '../../db/client.js';
import type { Entry } from './domain.js';

export type Tx = Parameters<Parameters<Db['transaction']>[0]>[0];
export type DbOrTx = Db | Tx;

export interface LedgerRow {
  kind: string;
  amountCents: number;
  rideId: string | null;
  createdAt: Date;
}

export class PaymentsRepo {
  constructor(private readonly db: Db) {}

  transaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    return this.db.transaction(fn);
  }

  /** Verrouille les portefeuilles (créés au besoin), toujours dans le même ordre. */
  async lockWallets(userIds: readonly string[], tx: Tx): Promise<void> {
    for (const id of [...new Set(userIds)].sort()) {
      await tx.execute(sql`INSERT INTO wallets (user_id) VALUES (${id}) ON CONFLICT DO NOTHING`);
      await tx.execute(sql`SELECT 1 FROM wallets WHERE user_id = ${id} FOR UPDATE`);
    }
  }

  async balance(account: string, db: DbOrTx = this.db): Promise<number> {
    const { rows } = await db.execute<{ total: string | null }>(
      sql`SELECT sum(amount_cents) AS total FROM wallet_ledger WHERE account = ${account}`,
    );
    return Number(rows[0]?.total ?? 0);
  }

  async operationExists(idempotencyKey: string, db: DbOrTx = this.db): Promise<boolean> {
    const { rows } = await db.execute(
      sql`SELECT 1 FROM wallet_ledger WHERE idempotency_key = ${`${idempotencyKey}#0`}`,
    );
    return rows.length > 0;
  }

  /**
   * Écrit une opération (écritures équilibrées, une seule fois par clé d'idempotence) et
   * met à jour le cache des soldes. Renvoie `false` si l'opération existait déjà.
   */
  async record(idempotencyKey: string, entries: readonly Entry[], rideId: string | null, tx: Tx): Promise<boolean> {
    if (await this.operationExists(idempotencyKey, tx)) return false;
    const operationId = randomUUID();
    for (const [i, e] of entries.entries()) {
      await tx.execute(sql`
        INSERT INTO wallet_ledger (idempotency_key, account, ride_id, kind, amount_cents, operation_id)
        VALUES (${`${idempotencyKey}#${i}`}, ${e.account}, ${rideId}, ${e.kind}, ${e.amountCents}, ${operationId})`);
    }
    const users = new Set(
      entries.filter((e) => /^(user|held):/.test(e.account)).map((e) => e.account.slice(e.account.indexOf(':') + 1)),
    );
    for (const id of users) await this.refreshCache(id, tx);
    return true;
  }

  /** Cache `wallets` recalculé depuis le registre (la source de vérité). */
  async refreshCache(userId: string, tx: Tx): Promise<void> {
    await tx.execute(sql`
      UPDATE wallets SET
        balance_cents = COALESCE((SELECT sum(amount_cents) FROM wallet_ledger WHERE account = ${`user:${userId}`}), 0),
        held_cents = COALESCE((SELECT sum(amount_cents) FROM wallet_ledger WHERE account = ${`held:${userId}`}), 0)
      WHERE user_id = ${userId}`);
  }

  async wallet(userId: string): Promise<{ balanceCents: number; heldCents: number }> {
    const { rows } = await this.db.execute<{ balance_cents: number; held_cents: number }>(
      sql`SELECT balance_cents, held_cents FROM wallets WHERE user_id = ${userId}`,
    );
    return { balanceCents: rows[0]?.balance_cents ?? 0, heldCents: rows[0]?.held_cents ?? 0 };
  }

  async history(userId: string, limit = 50): Promise<LedgerRow[]> {
    const { rows } = await this.db.execute<{ kind: string; amount_cents: number; ride_id: string | null; created_at: Date }>(sql`
      SELECT kind, amount_cents, ride_id, created_at FROM wallet_ledger
      WHERE account = ${`user:${userId}`} AND kind NOT IN ('hold', 'hold_release')
      ORDER BY created_at DESC, id LIMIT ${limit}`);
    return rows.map((r) => ({ kind: r.kind, amountCents: r.amount_cents, rideId: r.ride_id, createdAt: new Date(r.created_at) }));
  }

  async insertTopup(userId: string, amountCents: number, providerRef: string, status: string, tx: Tx): Promise<string> {
    const { rows } = await tx.execute<{ id: string }>(sql`
      INSERT INTO topups (user_id, amount_cents, provider_ref, status) VALUES (${userId}, ${amountCents}, ${providerRef}, ${status})
      ON CONFLICT (provider_ref) DO UPDATE SET status = EXCLUDED.status RETURNING id`);
    return rows[0]!.id;
  }

  async payment(rideId: string, payerId: string, tx: Tx) {
    const { rows } = await tx.execute<{ status: string; held_cents: number; share_cents: number; commission_cents: number }>(sql`
      SELECT status, held_cents, share_cents, commission_cents FROM payments
      WHERE ride_id = ${rideId} AND payer_id = ${payerId} FOR UPDATE`);
    return rows[0];
  }

  async upsertPayment(
    p: { rideId: string; payerId: string; payeeId: string; shareCents: number; commissionCents: number; heldCents: number; status: string },
    tx: Tx,
  ): Promise<void> {
    await tx.execute(sql`
      INSERT INTO payments (ride_id, payer_id, payee_id, share_cents, commission_cents, held_cents, status)
      VALUES (${p.rideId}, ${p.payerId}, ${p.payeeId}, ${p.shareCents}, ${p.commissionCents}, ${p.heldCents}, ${p.status})
      ON CONFLICT (ride_id, payer_id) DO NOTHING`);
  }

  async setPaymentStatus(rideId: string, payerId: string, status: string, paidAt: Date | null, tx: Tx): Promise<void> {
    await tx.execute(sql`
      UPDATE payments SET status = ${status}, paid_at = ${paidAt} WHERE ride_id = ${rideId} AND payer_id = ${payerId}`);
  }

  async heldPayments(rideId: string, tx: Tx): Promise<{ payerId: string; heldCents: number }[]> {
    const { rows } = await tx.execute<{ payer_id: string; held_cents: number }>(
      sql`SELECT payer_id, held_cents FROM payments WHERE ride_id = ${rideId} AND status = 'held'`,
    );
    return rows.map((r) => ({ payerId: r.payer_id, heldCents: r.held_cents }));
  }
}
