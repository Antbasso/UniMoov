import Fastify, { type FastifyInstance, type FastifyRequest } from 'fastify';
import {
  hasZodFastifySchemaValidationErrors,
  serializerCompiler,
  validatorCompiler,
  type ZodTypeProvider,
} from 'fastify-type-provider-zod';
import type { Config } from './config.js';
import { healthRoutes } from './modules/health/routes.js';
import type { PingDb } from './modules/health/service.js';
import { AppError, errorBody } from './shared/errors.js';

export interface AppDeps {
  config: Pick<Config, 'LOG_LEVEL'> & Partial<Pick<Config, 'TRUST_PROXY'>>;
  pingDb: PingDb;
  /** Destination des journaux (stdout par défaut) ; injectable pour les tests. */
  logStream?: { write: (line: string) => void };
}

export async function buildApp({ config, pingDb, logStream }: AppDeps): Promise<FastifyInstance> {
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
    // Erreurs client levées par Fastify (JSON mal formé, type de contenu, corps trop gros…).
    const status = (error as { statusCode?: unknown }).statusCode;
    if (typeof status === 'number' && status >= 400 && status < 500) {
      return reply.code(status).send(errorBody(clientErrorCode(status), 'Requête invalide'));
    }
    request.log.error({ err: error }, 'unhandled error');
    return reply.code(500).send(errorBody('internal_error', 'Erreur interne'));
  });

  app.setNotFoundHandler((_request, reply) =>
    reply.code(404).send(errorBody('not_found', 'Ressource introuvable')),
  );

  await app.register(healthRoutes, { pingDb });
  // Les modules métier seront montés sous /api/v1 (docs/api.md).

  return app;
}

function clientErrorCode(status: number): string {
  switch (status) {
    case 400:
      return 'bad_request';
    case 413:
      return 'payload_too_large';
    case 415:
      return 'unsupported_media_type';
    case 429:
      return 'rate_limited';
    default:
      return `http_${status}`;
  }
}
