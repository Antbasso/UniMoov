/** Politique de sécurité de l'authentification (cahier §1, AGENTS.md « Sécurité »). */
export const AUTH_POLICY = {
  codeLength: 6,
  codeTtlMinutes: 10,
  codeMaxAttempts: 5,
  codeResendCooldownSeconds: 60,
  accessTokenTtlSeconds: 15 * 60,
  refreshTokenTtlDays: 30,
  passwordMinLength: 8,
  passwordMaxLength: 128,
} as const;
