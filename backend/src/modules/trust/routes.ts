import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  disputeBody,
  disputeParams,
  disputeResponse,
  disputesResponse,
  escalateBody,
  rateBody,
  ratingsResponse,
  reliabilityResponse,
  reportBody,
  reportResponse,
  rideParams,
} from './schema.js';
import type { TrustService } from './service.js';

/** Notes, fiabilité, litiges, signalements (docs/api.md) ; appartenance vérifiée par le service. */
export const trustRoutes: FastifyPluginAsyncZod<{ service: TrustService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/me/reliability', { schema: { response: { 200: reliabilityResponse } } }, (request) =>
    service.reliability(request.userId),
  );

  app.get('/rides/:id/ratings', { schema: { params: rideParams, response: { 200: ratingsResponse } } }, (request) =>
    service.ratings(request.userId, request.params.id),
  );

  app.post(
    '/rides/:id/ratings',
    { schema: { params: rideParams, body: rateBody, response: { 204: z.null() } } },
    async (request, reply) => {
      await service.rate(request.userId, request.params.id, request.body.ratedUserId, request.body.stars);
      return reply.code(204).send(null);
    },
  );

  app.get('/rides/:id/disputes', { schema: { params: rideParams, response: { 200: disputesResponse } } }, async (request) => ({
    disputes: await service.disputes(request.userId, request.params.id),
  }));

  app.post(
    '/rides/:id/disputes',
    {
      schema: { params: rideParams, body: disputeBody, response: { 201: disputeResponse } },
      config: { rateLimit: { max: 10, timeWindow: '1 hour' } },
    },
    async (request, reply) => {
      const view = await service.openDispute(request.userId, request.params.id, request.body.reason, request.body.message ?? null);
      return reply.code(201).send(view);
    },
  );

  app.post(
    '/disputes/:id/escalate',
    {
      schema: { params: disputeParams, body: escalateBody, response: { 200: disputeResponse } },
      config: { rateLimit: { max: 10, timeWindow: '1 hour' } },
    },
    (request) => service.escalate(request.userId, request.params.id, request.body?.message ?? null),
  );

  app.post(
    '/reports',
    {
      schema: { body: reportBody, response: { 201: reportResponse } },
      config: { rateLimit: { max: 10, timeWindow: '1 hour' } },
    },
    async (request, reply) => {
      const result = await service.report(request.userId, request.body.targetUserId, request.body.reason, request.body.message ?? null);
      return reply.code(201).send(result);
    },
  );

  return Promise.resolve();
};
