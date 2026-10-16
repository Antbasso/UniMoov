import { z } from 'zod';

export const rideParams = z.object({ id: z.uuid() });
export const disputeParams = z.object({ id: z.uuid() });

export const disputeReason = z.enum(['cancellation_penalty', 'marked_absent', 'payment', 'driver_issue', 'other']);
export const reportReason = z.enum(['dangerous_driving', 'inappropriate_behaviour', 'fake_profile', 'other']);
/** Texte libre facultatif, transmis à l'équipe seulement (jamais aux autres utilisateurs ni aux journaux). */
const message = z.string().trim().min(1).max(1000).optional();

export const rateBody = z.object({ ratedUserId: z.uuid(), stars: z.number().int().min(1).max(5) });

export const ratingsResponse = z.strictObject({
  open: z.boolean(),
  closesAt: z.date(),
  people: z.array(
    z.strictObject({
      userId: z.uuid(),
      firstName: z.string(),
      photoUrl: z.string().nullable(),
      role: z.enum(['driver', 'passenger']),
      stars: z.number().int().nullable(),
    }),
  ),
});

export const reliabilityResponse = z.strictObject({
  score: z.number(),
  windowDays: z.number().int(),
  completedRides: z.number().int(),
  cancellations: z.strictObject({ early: z.number().int(), medium: z.number().int(), late: z.number().int() }),
  noShows: z.number().int(),
  ratingsCount: z.number().int(),
  averageStars: z.number().nullable(),
  events: z.array(
    z.strictObject({
      id: z.uuid(),
      kind: z.enum(['cancel_early', 'cancel_medium', 'cancel_late', 'no_show', 'correction']),
      rideId: z.uuid().nullable(),
      day: z.string().nullable(),
      createdAt: z.date(),
      disputeReason: disputeReason.nullable(),
    }),
  ),
});

export const disputeBody = z.object({ reason: disputeReason, message });
export const escalateBody = z.object({ message }).optional();

export const disputeResponse = z.strictObject({
  id: z.uuid(),
  rideId: z.uuid(),
  reason: disputeReason,
  level: z.number().int(),
  decision: z.enum(['upheld', 'corrected', 'escalated']),
  explanation: z.string(),
  createdAt: z.date(),
  escalatedAt: z.date().nullable(),
});
export const disputesResponse = z.strictObject({ disputes: z.array(disputeResponse) });

export const reportBody = z.object({ targetUserId: z.uuid(), reason: reportReason, message });
export const reportResponse = z.strictObject({ id: z.uuid() });
