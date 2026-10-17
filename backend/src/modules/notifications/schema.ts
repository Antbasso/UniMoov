import { z } from 'zod';

export const deviceBody = z.object({
  platform: z.enum(['android', 'ios']),
  pushToken: z.string().min(10).max(4096),
});
export const deviceDeleteBody = z.object({ pushToken: z.string().min(10).max(4096) });

const prefs = {
  match: z.boolean(),
  rideUpdate: z.boolean(),
  rideReminder: z.boolean(),
  chat: z.boolean(),
};
export const preferencesResponse = z.strictObject(prefs);
export const preferencesBody = z.strictObject(prefs).partial();
