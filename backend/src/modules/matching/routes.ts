import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { AppError } from '../../shared/errors.js';
import { isoWeekMonday } from '../../shared/time.js';
import {
  alternativesResponse,
  cancellationResponse,
  cancelResponse,
  createRideBody,
  idParams,
  inviteParams,
  proposal,
  proposalsResponse,
  searchQuery,
  suggestionsResponse,
  weekQuery,
} from './schema.js';
import type { MatchingService } from './service.js';

/** Propositions et recherche (docs/api.md) ; un utilisateur ne voit que ses trajets. */
export const matchingRoutes: FastifyPluginAsyncZod<{ service: MatchingService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/proposals', { schema: { querystring: weekQuery, response: { 200: proposalsResponse } }, config: { rateLimit: { max: 120, timeWindow: '1 minute' } } }, async (request) => {
    try {
      isoWeekMonday(request.query.week);
    } catch {
      throw new AppError(400, 'validation_error', 'Semaine invalide');
    }
    return { week: request.query.week, proposals: await service.listProposals(request.userId, request.query.week) };
  });

  // Trajet créé à la main par un conducteur (jour, sens, heure), qu'il accepte d'office.
  app.post(
    '/rides',
    { schema: { body: createRideBody, response: { 201: proposal } }, config: { rateLimit: { max: 20, timeWindow: '1 hour' } } },
    async (request, reply) => reply.code(201).send(await service.priced(request.userId, await service.createRide(request.userId, request.body))),
  );

  app.post('/proposals/:id/accept', { schema: { params: idParams, response: { 200: proposal } } }, async (request) =>
    service.priced(request.userId, await service.accept(request.userId, request.params.id)),
  );

  app.post(
    '/proposals/:id/decline',
    { schema: { params: idParams, response: { 204: z.null() } } },
    async (request, reply) => {
      await service.decline(request.userId, request.params.id);
      return reply.code(204).send(null);
    },
  );

  // Annulation après acceptation (cahier §8) : palier de pénalité affiché avant de confirmer.
  app.get(
    '/rides/:id/cancellation',
    { schema: { params: idParams, response: { 200: cancellationResponse } } },
    (request) => service.cancellation(request.userId, request.params.id),
  );

  app.post(
    '/rides/:id/cancel',
    { schema: { params: idParams, response: { 200: cancelResponse } } },
    (request) => service.cancel(request.userId, request.params.id),
  );

  app.get(
    '/proposals/:id/alternatives',
    // Même recherche que /search/rides : bornée elle aussi.
    { schema: { params: idParams, response: { 200: alternativesResponse } }, config: { rateLimit: { max: 30, timeWindow: '1 hour' } } },
    async (request) => ({ rides: await service.alternatives(request.userId, request.params.id) }),
  );

  // Conducteur uniquement : passagers supplémentaires et simulation du prix (cahier §4).
  app.get(
    '/rides/:id/suggestions',
    { schema: { params: idParams, response: { 200: suggestionsResponse } } },
    (request) => service.suggestions(request.userId, request.params.id),
  );

  app.post(
    '/rides/:id/suggestions/:userId/invite',
    { schema: { params: inviteParams, response: { 200: proposal } } },
    async (request) => service.priced(request.userId, await service.invite(request.userId, request.params.id, request.params.userId)),
  );

  // Conducteur : réponse à une demande de place (passager venu par la recherche).
  app.post(
    '/rides/:id/requests/:userId/approve',
    { schema: { params: inviteParams, response: { 200: proposal } } },
    async (request) =>
      service.priced(request.userId, await service.answerRequest(request.userId, request.params.id, request.params.userId, true)),
  );

  app.post(
    '/rides/:id/requests/:userId/reject',
    { schema: { params: inviteParams, response: { 200: proposal } } },
    async (request) =>
      service.priced(request.userId, await service.answerRequest(request.userId, request.params.id, request.params.userId, false)),
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
