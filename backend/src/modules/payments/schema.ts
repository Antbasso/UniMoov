import { z } from 'zod';

export const walletResponse = z.strictObject({
  balanceCents: z.number().int(),
  heldCents: z.number().int(),
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
