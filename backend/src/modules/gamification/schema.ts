import { z } from 'zod';

const levelKey = z.enum(['newcomer', 'regular', 'pillar', 'super', 'legend']);

export const achievementsResponse = z.strictObject({
  points: z.number().int(),
  level: z.strictObject({
    key: levelKey,
    min: z.number().int(),
    next: z.strictObject({ key: levelKey, min: z.number().int() }).nullable(),
  }),
  badges: z.array(z.strictObject({ key: z.string(), goal: z.number().int(), progress: z.number().int(), earned: z.boolean() })),
  impact: z.strictObject({
    rides: z.number().int(),
    sharedKm: z.number().int(),
    co2SavedKg: z.number().int(),
    paidCents: z.number().int(),
    receivedCents: z.number().int(),
  }),
  month: z.strictObject({ month: z.string(), points: z.number().int(), rank: z.number().int().nullable(), ranked: z.number().int() }),
  leaderboardVisible: z.boolean(),
});

export const leaderboardResponse = z.strictObject({
  month: z.string(),
  ranked: z.number().int(),
  entries: z.array(
    z.strictObject({
      rank: z.number().int(),
      firstName: z.string().nullable(),
      photoUrl: z.string().nullable(),
      points: z.number().int(),
      level: levelKey,
      me: z.boolean(),
    }),
  ),
  me: z.strictObject({ rank: z.number().int(), points: z.number().int() }).nullable(),
});
