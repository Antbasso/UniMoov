import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { pickupBody, priceResponse, ride, rideParams } from './schema.js';
import type { RidesService } from './service.js';

/** Trajets confirmés (docs/api.md) : accès réservé aux participants acceptés. */
export const ridesRoutes: FastifyPluginAsyncZod<{ service: RidesService }> = (app, { service }) => {
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

  return Promise.resolve();
};
