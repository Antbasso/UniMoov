import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { deleteAccountBody, exportResponse } from './schema.js';
import type { AccountService } from './service.js';

/** Export et suppression du compte (RGPD) ; uniquement le sien. */
export const accountRoutes: FastifyPluginAsyncZod<{ service: AccountService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get(
    '/me/export',
    { schema: { response: { 200: exportResponse } }, config: { rateLimit: { max: 5, timeWindow: '1 hour' } } },
    async (request, reply) => {
      reply.header('content-disposition', 'attachment; filename="uni-moov-mes-donnees.json"');
      return service.export(request.userId);
    },
  );

  app.delete(
    '/me',
    { schema: { body: deleteAccountBody, response: { 204: z.null() } }, config: { rateLimit: { max: 5, timeWindow: '15 minutes' } } },
    async (request, reply) => {
      await service.delete(request.userId, request.body.password);
      return reply.code(204).send(null);
    },
  );

  return Promise.resolve();
};
