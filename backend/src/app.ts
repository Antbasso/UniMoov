import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import Fastify, { type FastifyInstance, type FastifyRequest } from 'fastify';
import {
  hasZodFastifySchemaValidationErrors,
  jsonSchemaTransform,
  serializerCompiler,
  validatorCompiler,
  type ZodTypeProvider,
} from 'fastify-type-provider-zod';
import type { Config } from './config.js';
import type { Db } from './db/client.js';
import { AuthRepo } from './modules/auth/repo.js';
import { authRoutes } from './modules/auth/routes.js';
import { AuthService } from './modules/auth/service.js';
import { AUTH_POLICY } from './modules/auth/policy.js';
import { healthRoutes } from './modules/health/routes.js';
import type { PingDb } from './modules/health/service.js';
import { ProfileRepo } from './modules/profile/repo.js';
import { profileRoutes } from './modules/profile/routes.js';
import { ProfileService } from './modules/profile/service.js';
import { SettingsService } from './modules/settings/service.js';
import { authenticatePlugin } from './plugins/authenticate.js';
import { AppError, errorBody } from './shared/errors.js';
import type { GeocodingProvider } from './shared/geocoding/geocoding-provider.js';
import type { MailProvider } from './shared/mail/mail-provider.js';

/** Dépendances des modules métier ; absentes, seule la route /health est montée. */
export interface AppModules {
  db: Db;
  jwtSecret: string;
  mail: MailProvider;
  geocoding: GeocodingProvider;
  clock?: () => Date;
  /** Limites de débit (désactivables pour les tests d'intégration hors test dédié). */
  rateLimit?: boolean;
}

export interface AppDeps {
  config: Pick<Config, 'LOG_LEVEL'> & Partial<Pick<Config, 'TRUST_PROXY' | 'NODE_ENV'>>;
  pingDb: PingDb;
  /** Destination des journaux (stdout par défaut) ; injectable pour les tests. */
  logStream?: { write: (line: string) => void };
  modules?: AppModules;
}

export async function buildApp({ config, pingDb, logStream, modules }: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    // Derrière Caddy en production : l'IP réelle sert à la limite de débit, jamais aux journaux.
    trustProxy: config.TRUST_PROXY ?? false,
    logger: {
      level: config.LOG_LEVEL,
      ...(logStream ? { stream: logStream } : {}),
      // Aucune donnée personnelle ni secret dans les journaux (AGENTS.md) : ni IP, ni en-têtes,
      // ni paramètres d'URL (jetons, coordonnées).
      serializers: {
        req: (request: FastifyRequest) => ({
          method: request.method,
          route: request.routeOptions.url ?? 'unknown',
        }),
      },
    },
  }).withTypeProvider<ZodTypeProvider>();

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  app.setErrorHandler((error, request, reply) => {
    if (hasZodFastifySchemaValidationErrors(error)) {
      return reply.code(400).send(errorBody('validation_error', 'Requête invalide'));
    }
    if (error instanceof AppError) {
      return reply.code(error.statusCode).send(errorBody(error.code, error.message));
    }
    // Erreurs client levées par Fastify et ses plugins (JSON mal formé, limite de débit…).
    const status = (error as { statusCode?: unknown }).statusCode;
    if (typeof status === 'number' && status >= 400 && status < 500) {
      const { code, message } = clientError(status);
      return reply.code(status).send(errorBody(code, message));
    }
    request.log.error({ err: error }, 'unhandled error');
    return reply.code(500).send(errorBody('internal_error', 'Erreur interne'));
  });

  app.setNotFoundHandler((_request, reply) =>
    reply.code(404).send(errorBody('not_found', 'Ressource introuvable')),
  );

  await app.register(rateLimit, {
    global: false,
    ...(modules?.rateLimit === false ? { allowList: () => true } : {}),
  });

  if (config.NODE_ENV === 'development') {
    // Contrat OpenAPI généré depuis les schémas Zod, publié en développement uniquement.
    await app.register(swagger, {
      openapi: { info: { title: 'Uni-Moov API', version: '1' } },
      transform: jsonSchemaTransform,
    });
    await app.register(swaggerUi, { routePrefix: '/docs' });
  }

  await app.register(healthRoutes, { pingDb });

  if (modules) {
    const clock = modules.clock ?? (() => new Date());
    await app.register(authenticatePlugin, {
      secret: modules.jwtSecret,
      accessTokenTtlSeconds: AUTH_POLICY.accessTokenTtlSeconds,
    });
    const settings = new SettingsService(modules.db);
    const authService = new AuthService({
      repo: new AuthRepo(modules.db),
      mail: modules.mail,
      settings,
      clock,
      secret: modules.jwtSecret,
      signAccessToken: (userId) => app.jwt.sign({ sub: userId }),
    });
    const profileService = new ProfileService(new ProfileRepo(modules.db), modules.geocoding, clock);

    await app.register(
      async (api) => {
        await api.register(authRoutes, { service: authService });
        await api.register(profileRoutes, { service: profileService });
      },
      { prefix: '/api/v1' },
    );
  }

  return app;
}

function clientError(status: number): { code: string; message: string } {
  switch (status) {
    case 400:
      return { code: 'bad_request', message: 'Requête invalide' };
    case 413:
      return { code: 'payload_too_large', message: 'Requête invalide' };
    case 415:
      return { code: 'unsupported_media_type', message: 'Requête invalide' };
    case 429:
      return { code: 'rate_limited', message: 'Trop de tentatives, réessaie dans quelques minutes' };
    default:
      return { code: `http_${status}`, message: 'Requête invalide' };
  }
}
