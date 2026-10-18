import { z } from 'zod';
import { ONBOARDING_STEPS } from './domain.js';

const name = z.string().trim().min(1).max(60);
const roleMode = z.enum(['auto', 'always_driver', 'always_passenger']);
const navApp = z.enum(['google_maps', 'waze', 'apple_maps']);
const stepStatus = z.enum(['done', 'skipped']);
const isoDate = z.iso.date();

export const vehicleSchema = z.object({
  consumptionLPer100km: z.number().min(2).max(20),
  defaultSeats: z.number().int().min(1).max(8),
  maxDetourMinutes: z.number().int().min(0).max(60),
});

export const meResponse = z.object({
  id: z.uuid(),
  universityEmail: z.string(),
  firstName: z.string(),
  lastName: z.string(),
  photoUrl: z.string().nullable(),
  campusId: z.uuid().nullable(),
  home: z
    .object({ address: z.string(), lat: z.number(), lon: z.number(), sector: z.string() })
    .nullable(),
  roleMode,
  defaultNavApp: navApp.nullable(),
  reliabilityScore: z.number(),
  vehicle: vehicleSchema.nullable(),
  onboarding: z.object({
    steps: z.partialRecord(z.enum(ONBOARDING_STEPS), stepStatus),
    nextStep: z.enum(ONBOARDING_STEPS).nullable(),
    completed: z.boolean(),
  }),
  discoveryMode: z.boolean(),
  pausedToday: z.boolean(),
});
export type MeResponse = z.infer<typeof meResponse>;

export const patchMeBody = z
  .object({ firstName: name, lastName: name })
  .partial()
  .refine((body) => Object.keys(body).length > 0, 'Aucun champ à modifier');

export const addressBody = z.object({ address: z.string().trim().min(5).max(200) });
export const addressQuery = z.object({ q: z.string().trim().min(3).max(200) });
export const addressSuggestions = z.object({ suggestions: z.array(z.object({ label: z.string() })) });

export const preferencesBody = z
  .object({ roleMode, defaultNavApp: navApp.nullable() })
  .partial()
  .refine((body) => Object.keys(body).length > 0, 'Aucun champ à modifier');

export const onboardingParams = z.object({ step: z.enum(ONBOARDING_STEPS) });
export const onboardingBody = z.object({ status: stepStatus });

export const pauseSchema = z.object({
  id: z.uuid(),
  startsOn: isoDate,
  endsOn: isoDate,
  /** `weekly:N` (1-8), `monthly:N` (1-6) ou `days:1,3` (jours ISO), voir docs/api.md. */
  recurrence: z
    .string()
    .regex(/^(weekly:[1-8]|monthly:[1-6]|days:[1-7](,[1-7]){0,6})$/)
    .nullable(),
  repeatUntil: isoDate.nullable(),
});
export const pauseBody = pauseSchema.omit({ id: true }).extend({ repeatUntil: isoDate.nullable().default(null) });
export const pausesResponse = z.object({ pauses: z.array(pauseSchema) });
export const idParams = z.object({ id: z.uuid() });

export const publicProfileResponse = z.object({
  id: z.uuid(),
  firstName: z.string(),
  photoUrl: z.string().nullable(),
  reliabilityScore: z.number(),
});
