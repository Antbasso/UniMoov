import { z } from 'zod';

/** Zone visible de la carte ; au plus environ 25 km de côté. */
export const MAX_SPAN_DEG = 0.25;

export const meetingSpotsQuery = z
  .object({
    south: z.coerce.number().min(-85).max(85),
    west: z.coerce.number().min(-180).max(180),
    north: z.coerce.number().min(-85).max(85),
    east: z.coerce.number().min(-180).max(180),
  })
  .refine((b) => b.north > b.south && b.east > b.west, 'Zone vide')
  .refine((b) => b.north - b.south <= MAX_SPAN_DEG && b.east - b.west <= MAX_SPAN_DEG, 'Zone trop grande');

export const meetingSpotsResponse = z.strictObject({
  spots: z.array(
    z.strictObject({ kind: z.enum(['parking', 'carpool']), name: z.string().nullable(), lat: z.number(), lon: z.number() }),
  ),
  /** `false` : le service de lieux ne répond pas ; la carte reste utilisable sans eux. */
  available: z.boolean(),
});
