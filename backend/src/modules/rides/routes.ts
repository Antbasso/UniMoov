import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import type { RideLifecycle } from './lifecycle.js';
import {
  navigationResponse,
  participantParams,
  pickupBody,
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

  app.get('/rides/:id', { schema: { params: rideParams, response: { 200: ride } } }, (request) =>
    service.get(request.userId, request.params.id),
  );

  app.get('/rides/:id/price', { schema: { params: rideParams, response: { 200: priceResponse } } }, async (request) => ({
    price: await service.price(request.userId, request.params.id),
  }));

  app.put(
    '/rides/:id/me/pickup',
    { schema: { params: rideParams, body: pickupBody, response: { 204: z.null() } } },
    async (request, reply) => {
      await service.setPickup(request.userId, request.params.id, request.body);
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
    payment: await lifecycle.requestPresence(request.userId, request.params.id),
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
