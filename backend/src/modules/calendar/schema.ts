import { z } from 'zod';

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Heure au format HH:MM');
const isoDate = z.iso.date();

export const connectBody = z.object({
  provider: z.literal('ics'),
  url: z.string().trim().min(10).max(2000),
  /** Consentement explicite exigé (AGENTS.md) : seule la valeur `true` est acceptée. */
  consent: z.literal(true),
});

export const connectionSchema = z.object({
  id: z.uuid(),
  provider: z.string(),
  consentedAt: z.date(),
  lastSyncedAt: z.date().nullable(),
  lastError: z.string().nullable(),
});

export const connectionResponse = z.object({ connection: connectionSchema.nullable() });
export const syncResponse = z.object({ connection: connectionSchema, changedDays: z.array(isoDate) });

export const manualDay = z.object({
  weekday: z.number().int().min(1).max(7),
  startTime: hhmm,
  endTime: hhmm,
});
export const manualBody = z.object({ days: z.array(manualDay).max(7) });
export const manualResponse = z.object({ days: z.array(manualDay), changedDays: z.array(isoDate).optional() });

export const scheduleQuery = z
  .object({ from: isoDate, to: isoDate })
  .refine((q) => q.from < q.to, 'from doit précéder to');
export const scheduleResponse = z.object({
  slots: z.array(z.object({ day: isoDate, start: z.date(), end: z.date() })),
});
export const idParams = z.object({ id: z.uuid() });
