import { z } from 'zod';

/** Variables d'environnement validées au démarrage (docs/architecture.md §10). */
const envSchema = z
  .object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().min(1).default('0.0.0.0'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
  /** `true` uniquement derrière un reverse proxy de confiance (Caddy). */
  TRUST_PROXY: z.stringbool().default(false),
  /** Secret de signature des JWT et des codes (32 caractères minimum, jamais commité). */
  JWT_SECRET: z.string().min(32),
  /** `console` : le code s'affiche dans les journaux de l'API (développement uniquement). */
  MAIL_PROVIDER: z.enum(['console']).default('console'),
  GEOCODING_PROVIDER: z.enum(['ban', 'fake']).default('ban'),
  /** Géoplateforme (successeur de api-adresse.data.gouv.fr), gratuite pour la France. */
  GEOCODING_URL: z.url().default('https://data.geopf.fr/geocodage/search'),
})
  .refine((env) => env.NODE_ENV !== 'production' || env.MAIL_PROVIDER !== 'console', {
    path: ['MAIL_PROVIDER'],
    message: 'console interdit en production',
  });

export type Config = z.infer<typeof envSchema>;

export class ConfigError extends Error {
  override readonly name = 'ConfigError';
}

/** Lit et valide la configuration ; n'affiche jamais les valeurs (secrets possibles). */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    const fields = parsed.error.issues.map((issue) => issue.path.join('.')).join(', ');
    throw new ConfigError(`Configuration invalide : ${fields}`);
  }
  return parsed.data;
}
