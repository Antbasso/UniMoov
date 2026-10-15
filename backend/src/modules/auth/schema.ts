import { z } from 'zod';
import { AUTH_POLICY } from './policy.js';

// Normalisé avant validation : espaces et majuscules tolérés à la saisie.
const email = z.string().trim().toLowerCase().pipe(z.email().max(254));
const password = z.string().min(AUTH_POLICY.passwordMinLength).max(AUTH_POLICY.passwordMaxLength);
const name = z.string().trim().min(1).max(60);

export const requestCodeBody = z.object({ universityEmail: email });

export const verifyBody = z.object({
  universityEmail: email,
  code: z.string().regex(/^\d{6}$/),
  firstName: name,
  lastName: name,
  password,
});

export const loginBody = z.object({ universityEmail: email, password: z.string().min(1).max(256) });

export const refreshBody = z.object({ refreshToken: z.string().min(20).max(200) });

export const tokensResponse = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  accessTokenExpiresIn: z.number().int(),
});

export type TokensResponse = z.infer<typeof tokensResponse>;
