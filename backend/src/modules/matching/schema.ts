import { z } from 'zod';

const direction = z.enum(['to_campus', 'from_campus']);

/**
 * Personne vue avant acceptation mutuelle. Schéma strict : un champ non listé ici (nom de
 * famille, adresse, coordonnées exactes) ne peut pas sortir de l'API, même par erreur.
 */
export const publicPerson = z.strictObject({
  userId: z.uuid(),
  firstName: z.string(),
  photoUrl: z.string().nullable(),
  sector: z.object({ lat: z.number(), lon: z.number() }).nullable(),
  reliabilityScore: z.number(),
  detourMinutes: z.number().int(),
  status: z.string(),
});

export const proposal = z.strictObject({
  id: z.uuid(),
  day: z.iso.date(),
  direction,
  time: z.date(),
  role: z.enum(['driver', 'passenger']),
  myStatus: z.string(),
  rideStatus: z.string(),
  seatsTotal: z.number().int(),
  seatsTaken: z.number().int(),
  detourMinutes: z.number().int(),
  driver: publicPerson.nullable(),
  passengers: z.array(publicPerson),
});

export const joinableRide = z.strictObject({
  rideId: z.uuid(),
  day: z.iso.date(),
  direction,
  time: z.date(),
  seatsLeft: z.number().int(),
  driver: publicPerson,
});

export const weekQuery = z.object({ week: z.string().regex(/^\d{4}-W\d{2}$/) });
export const proposalsResponse = z.object({ week: z.string(), proposals: z.array(proposal) });
export const idParams = z.object({ id: z.uuid() });
export const alternativesResponse = z.object({ rides: z.array(joinableRide) });
export const searchQuery = z.object({
  day: z.iso.date(),
  direction,
  time: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/)
    .optional(),
});

export const suggestionsResponse = z.strictObject({
  seatsLeft: z.number().int(),
  current: z
    .strictObject({ persons: z.number().int(), shareCents: z.number().int(), passengerPaysCents: z.number().int() })
    .nullable(),
  suggestions: z.array(
    z.strictObject({
      person: publicPerson,
      withinDetourLimit: z.boolean(),
      shareCents: z.number().int(),
      passengerPaysCents: z.number().int(),
    }),
  ),
});
export const inviteParams = z.object({ id: z.uuid(), userId: z.uuid() });

const cancelTier = z.enum(['early', 'medium', 'late']);
export const cancellationResponse = z.strictObject({ role: z.enum(['driver', 'passenger']), tier: cancelTier });
export const cancelResponse = z.strictObject({ tier: cancelTier });

export const createRideBody = z.object({
  day: z.iso.date(),
  direction,
  time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
});
