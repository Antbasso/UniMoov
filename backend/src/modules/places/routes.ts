import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { meetingSpotsQuery, meetingSpotsResponse } from './schema.js';
import type { PlacesService } from './service.js';

/** Lieux publics pour se retrouver (docs/api.md). */
export const placesRoutes: FastifyPluginAsyncZod<{ service: PlacesService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get(
    '/places/meeting-spots',
    {
      schema: { querystring: meetingSpotsQuery, response: { 200: meetingSpotsResponse } },
      config: { rateLimit: { max: 120, timeWindow: '1 hour' } },
    },
    (request) => service.meetingSpots(request.query),
  );

  return Promise.resolve();
};
