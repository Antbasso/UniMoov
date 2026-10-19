import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import type { RideLifecycle } from './lifecycle.js';
import {
  historyResponse,
  navigationResponse,
  previewResponse,
  participantParams,
  pickupAnswerBody,
  pickupBody,
  pickupProposalBody,
  presenceResponse,
  priceResponse,
  ride,
  rideParams,
} from './schema.js';
import type { RidesService } from './service.js';

/** Trajets confirmés (docs/api.md) : accès réservé aux participants acceptés. */
export const ridesRoutes: FastifyPluginAsyncZod<{ service: RidesService; lifecycle: RideLifecycle }> = (
  app,
  { service, lifecycle },
) => {
  app.addHook('preHandler', app.authenticate);

  // Trajets terminés (historique du profil) ; route fixe, prioritaire sur /rides/:id.
  app.get('/rides/history', { schema: { response: { 200: historyResponse } } }, async (request) => ({
    rides: await service.history(request.userId),
  }));

  // Aperçu avant confirmation (proposés compris) : un appel d'itinéraire, puis gardé en mémoire.
  app.get(
    '/rides/:id/preview',
    { schema: { params: rideParams, response: { 200: previewResponse } }, config: { rateLimit: { max: 60, timeWindow: '1 hour' } } },
    (request) => service.preview(request.userId, request.params.id),
  );

  app.get('/rides/:id', { schema: { params: rideParams, response: { 200: ride } } }, (request) =>
    service.get(request.userId, request.params.id),
  );

  app.get('/rides/:id/price', { schema: { params: rideParams, response: { 200: priceResponse } } }, async (request) => ({
    price: await service.price(request.userId, request.params.id),
  }));

  app.put(
    '/rides/:id/me/pickup',
    // Chaque changement relance un calcul d'itinéraire (quota externe partagé).
    { schema: { params: rideParams, body: pickupBody, response: { 204: z.null() } }, config: { rateLimit: { max: 10, timeWindow: '1 hour' } } },
    async (request, reply) => {
      await service.setPickup(request.userId, request.params.id, request.body);
      return reply.code(204).send(null);
    },
  );

  // Le conducteur propose un point de rencontre à un passager ; le passager répond.
  app.put(
    '/rides/:id/participants/:userId/pickup-proposal',
    {
      schema: { params: participantParams, body: pickupProposalBody, response: { 204: z.null() } },
      config: { rateLimit: { max: 20, timeWindow: '1 hour' } },
    },
    async (request, reply) => {
      await service.proposePickup(request.userId, request.params.id, request.params.userId, request.body);
      return reply.code(204).send(null);
    },
  );

  app.post(
    '/rides/:id/me/pickup-proposal',
    {
      schema: { params: rideParams, body: pickupAnswerBody, response: { 204: z.null() } },
      config: { rateLimit: { max: 10, timeWindow: '1 hour' } },
    },
    async (request, reply) => {
      await service.answerPickupProposal(request.userId, request.params.id, request.body.accept);
      return reply.code(204).send(null);
    },
  );

  const noContent = { schema: { params: rideParams, response: { 204: z.null() } } };

  // Départ (conducteur) : suivi ouvert, retenue du prix estimé sur les portefeuilles.
  app.post('/rides/:id/start', noContent, async (request, reply) => {
    await lifecycle.start(request.userId, request.params.id);
    return reply.code(204).send(null);
  });

  app.post(
    '/rides/:id/participants/:userId/picked-up',
    { schema: { params: participantParams, response: { 204: z.null() } } },
    async (request, reply) => {
      await lifecycle.pickedUp(request.userId, request.params.id, request.params.userId);
      return reply.code(204).send(null);
    },
  );

  // Présence demandée par le passager : comparaison des dernières positions des deux téléphones.
  app.post('/rides/:id/presence', { schema: { params: rideParams, response: { 200: presenceResponse } } }, async (request) => ({
    status: await lifecycle.requestPresence(request.userId, request.params.id),
  }));

  app.post('/rides/:id/finish', noContent, async (request, reply) => {
    await lifecycle.finish(request.params.id, request.userId);
    return reply.code(204).send(null);
  });

  app.get('/rides/:id/navigation', { schema: { params: rideParams, response: { 200: navigationResponse } } }, (request) =>
    lifecycle.navigation(request.userId, request.params.id),
  );

  return Promise.resolve();
};
