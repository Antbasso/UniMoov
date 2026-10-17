import { z } from 'zod';

export const deleteAccountBody = z.object({ password: z.string().min(1).max(200) });

/** Export libre (objets imbriqués) : le contenu est décrit dans docs/api.md. */
export const exportResponse = z.record(z.string(), z.unknown());
