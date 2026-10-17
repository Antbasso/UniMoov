import { z } from 'zod';

/**
 * Trajet confirmé, vu par un participant accepté. Schémas stricts : seuls ces champs
 * sortent de l'API (le nom de famille n'est rempli qu'entre conducteur et passager).
 */
const stop = z.strictObject({
  order: z.number().int(),
  kind: z.enum(['driver', 'passenger', 'campus']),
  userId: z.uuid().nullable(),
  firstName: z.string().nullable(),
  lastName: z.string().nullable(),
  label: z.string(),
  lat: z.number(),
  lon: z.number(),
  eta: z.date().nullable(),
  isMeetingPoint: z.boolean(),
  pickedUp: z.boolean(),
  presenceValidated: z.boolean(),
});

export const price = z.strictObject({
  estimated: z.literal(true),
  totalCostCents: z.number().int(),
  persons: z.number().int(),
  shareCents: z.number().int(),
  commissionCents: z.number().int(),
  passengerPaysCents: z.number().int(),
  driverReceivesCents: z.number().int(),
  youPayCents: z.number().int().nullable(),
  youReceiveCents: z.number().int().nullable(),
});

export const ride = z.strictObject({
  id: z.uuid(),
  day: z.iso.date(),
  direction: z.enum(['to_campus', 'from_campus']),
  time: z.date(),
  status: z.string(),
  role: z.enum(['driver', 'passenger']),
  /** Statut de la personne qui lit : `absent` après une clôture sans validation de présence. */
  myStatus: z.string(),
  seatsTotal: z.number().int(),
  distanceM: z.number().int().nullable(),
  durationS: z.number().int().nullable(),
  routeEstimated: z.boolean(),
  route: z.array(z.tuple([z.number(), z.number()])),
  stops: z.array(stop),
  price: price.nullable(),
});

export const rideParams = z.object({ id: z.uuid() });
export const priceResponse = z.object({ price: price.nullable() });

export const pickupBody = z.object({
  useMeetingPoint: z.boolean(),
  label: z.string().trim().min(1).max(120).optional(),
  lat: z.number().min(-85).max(85).optional(),
  lon: z.number().min(-180).max(180).optional(),
});

export const participantParams = z.object({ id: z.uuid(), userId: z.uuid() });
export const presenceResponse = z.object({ status: z.enum(['validated', 'already']) });

export const navigationResponse = z.strictObject({
  stops: z.array(
    z.strictObject({
      order: z.number().int(),
      kind: z.enum(['passenger', 'destination']),
      userId: z.uuid().nullable(),
      firstName: z.string().nullable(),
      label: z.string(),
      lat: z.number(),
      lon: z.number(),
      eta: z.date().nullable(),
      pickedUp: z.boolean(),
    }),
  ),
  links: z.strictObject({
    googleMaps: z.string(),
    appleMaps: z.string(),
    waze: z.strictObject({ nextStop: z.string() }),
  }),
  supportsMultiStop: z.strictObject({ googleMaps: z.boolean(), appleMaps: z.boolean(), waze: z.boolean() }),
});
