import { z } from 'zod';

export const walletResponse = z.strictObject({
  balanceCents: z.number().int(),
  heldCents: z.number().int(),
  pendingCents: z.number().int(),
  history: z.array(
    z.strictObject({
      kind: z.string(),
      amountCents: z.number().int(),
      rideId: z.uuid().nullable(),
      createdAt: z.date(),
    }),
  ),
});

export const topupBody = z.object({ amountCents: z.number().int().positive().max(50_000) });
export const topupHeaders = z.object({ 'idempotency-key': z.string().min(8).max(100) });
export const topupResponse = z.object({ status: z.string(), wallet: walletResponse });

/** Retrait vers un IBAN (SEPA) : l'IBAN est transmis au prestataire, jamais renvoyé. */
export const payoutBody = z.object({
  amountCents: z.number().int().min(1).max(1_000_000),
  iban: z.string().trim().min(15).max(42),
  holderName: z.string().trim().min(2).max(70),
});
