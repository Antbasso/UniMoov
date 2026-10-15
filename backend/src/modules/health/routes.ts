import type { FastifyPluginCallbackZod } from 'fastify-type-provider-zod';
import { healthResponse } from './schema.js';
import { checkHealth, type PingDb } from './service.js';

export const healthRoutes: FastifyPluginCallbackZod<{ pingDb: PingDb }> = (app, { pingDb }, done) => {
  app.get(
    '/health',
    { schema: { response: { 200: healthResponse, 503: healthResponse } } },
    async (_request, reply) => {
      const health = await checkHealth(pingDb);
      return reply.code(health.status === 'ok' ? 200 : 503).send(health);
    },
  );
  done();
};
