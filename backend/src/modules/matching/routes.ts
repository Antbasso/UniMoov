import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { AppError } from '../../shared/errors.js';
import { isoWeekMonday } from '../../shared/time.js';
import {
  alternativesResponse,
  idParams,
  proposal,
  proposalsResponse,
  searchQuery,
  weekQuery,
} from './schema.js';
import type { MatchingService } from './service.js';

/** Propositions et recherche (docs/api.md) ; un utilisateur ne voit que ses trajets. */
export const matchingRoutes: FastifyPluginAsyncZod<{ service: MatchingService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/proposals', { schema: { querystring: weekQuery, response: { 200: proposalsResponse } } }, async (request) => {
    try {
      isoWeekMonday(request.query.week);
    } catch {
      throw new AppError(400, 'validation_error', 'Semaine invalide');
    }
    return { week: request.query.week, proposals: await service.listProposals(request.userId, request.query.week) };
  });

  app.post('/proposals/:id/accept', { schema: { params: idParams, response: { 200: proposal } } }, (request) =>
    service.accept(request.userId, request.params.id),
  );

  app.post(
    '/proposals/:id/decline',
    { schema: { params: idParams, response: { 204: z.null() } } },
    async (request, reply) => {
      await service.decline(request.userId, request.params.id);
      return reply.code(204).send(null);
    },
  );

  app.get(
    '/proposals/:id/alternatives',
    { schema: { params: idParams, response: { 200: alternativesResponse } } },
    async (request) => ({ rides: await service.alternatives(request.userId, request.params.id) }),
  );

  app.get(
    '/search/rides',
    {
      schema: { querystring: searchQuery, response: { 200: alternativesResponse } },
      // Quota quotidien par utilisateur dans le service, plus une limite par IP contre le scraping.
      config: { rateLimit: { max: 30, timeWindow: '1 hour' } },
    },
    async (request) => ({ rides: await service.search(request.userId, request.query) }),
  );

  return Promise.resolve();
};
