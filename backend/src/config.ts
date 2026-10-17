import { z } from 'zod';

/** Valeurs de `.env.example` : jamais en production. */
const EXAMPLE_SECRETS = new Set([
  'dev-secret-a-remplacer-par-32-caracteres-min',
  'ZGV2LWNsZS1hLXJlbXBsYWNlci0zMi1vY3RldHMhISE=',
]);

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
  MAIL_PROVIDER: z.enum(['console', 'brevo']).default('console'),
  /** Clé de l'API transactionnelle Brevo (secret, jamais commité). */
  BREVO_API_KEY: z.string().optional(),
  /** Expéditeur des mails, sur un domaine vérifié chez le fournisseur (pas une messagerie gratuite). */
  MAIL_FROM: z.union([z.email(), z.literal('')]).optional(),
  GEOCODING_PROVIDER: z.enum(['ban', 'fake']).default('ban'),
  /** Géoplateforme (successeur de api-adresse.data.gouv.fr), gratuite pour la France. */
  GEOCODING_URL: z.url().default('https://data.geopf.fr/geocodage/search'),
  /** Clé AES-256 (32 octets en base64) des liens d'agenda privés, jamais commitée. */
  CALENDAR_ENCRYPTION_KEY: z
    .base64()
    .refine((value) => Buffer.from(value, 'base64').length === 32, '32 octets attendus'),
  /** `ors` : OpenRouteService (clé requise) ; `estimate` : lignes droites, sans appel externe. */
  ROUTING_PROVIDER: z.enum(['ors', 'estimate']).default('estimate'),
  ORS_API_KEY: z.string().optional(),
  /** Appels quotidiens autorisés (palier gratuit d'OpenRouteService), alerte à 80 %. */
  ROUTING_DAILY_QUOTA: z.coerce.number().int().min(1).default(2000),
  /** `fake` : portefeuille simulé (aucun argent réel), interdit en production sauf répétition. */
  PAYMENT_PROVIDER: z.enum(['fake']).default('fake'),
  /** Répétition du pilote en production sans argent réel : autorise explicitement `fake`. */
  ALLOW_FAKE_PAYMENTS: z.stringbool().default(false),
  /** `fcm` : Firebase Cloud Messaging (clé de compte de service) ; `log` : journal seulement. */
  PUSH_PROVIDER: z.enum(['log', 'fcm']).default('log'),
  /** Chemin du fichier JSON de la clé du compte de service Firebase (secret, jamais commité). */
  FCM_SERVICE_ACCOUNT_FILE: z.string().optional(),
  /** Tâches planifiées (synchronisation des agendas, génération hebdomadaire). */
  JOBS_ENABLED: z.stringbool().default(true),
})
  .refine((env) => env.NODE_ENV !== 'production' || env.MAIL_PROVIDER !== 'console', {
    path: ['MAIL_PROVIDER'],
    message: 'console interdit en production',
  })
  .refine((env) => env.NODE_ENV !== 'production' || env.PAYMENT_PROVIDER !== 'fake' || env.ALLOW_FAKE_PAYMENTS, {
    path: ['PAYMENT_PROVIDER'],
    message: 'fake interdit en production (ALLOW_FAKE_PAYMENTS=true pour une répétition)',
  })
  .refine((env) => env.NODE_ENV !== 'production' || !EXAMPLE_SECRETS.has(env.JWT_SECRET), {
    path: ['JWT_SECRET'],
    message: 'valeur d’exemple interdite en production',
  })
  .refine((env) => env.NODE_ENV !== 'production' || !EXAMPLE_SECRETS.has(env.CALENDAR_ENCRYPTION_KEY), {
    path: ['CALENDAR_ENCRYPTION_KEY'],
    message: 'valeur d’exemple interdite en production',
  })
  .refine((env) => env.MAIL_PROVIDER !== 'brevo' || Boolean(env.BREVO_API_KEY), {
    path: ['BREVO_API_KEY'],
    message: 'clé requise avec MAIL_PROVIDER=brevo',
  })
  .refine((env) => env.MAIL_PROVIDER !== 'brevo' || Boolean(env.MAIL_FROM), {
    path: ['MAIL_FROM'],
    message: 'expéditeur requis avec MAIL_PROVIDER=brevo',
  })
  .refine((env) => env.ROUTING_PROVIDER !== 'ors' || Boolean(env.ORS_API_KEY), {
    path: ['ORS_API_KEY'],
    message: 'clé requise avec ROUTING_PROVIDER=ors',
  })
  .refine((env) => env.PUSH_PROVIDER !== 'fcm' || Boolean(env.FCM_SERVICE_ACCOUNT_FILE), {
    path: ['FCM_SERVICE_ACCOUNT_FILE'],
    message: 'fichier requis avec PUSH_PROVIDER=fcm',
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
