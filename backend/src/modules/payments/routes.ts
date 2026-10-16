import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { topupBody, topupHeaders, topupResponse, walletResponse } from './schema.js';
import type { WalletService } from './service.js';

/** Portefeuille (docs/api.md) : uniquement le sien. */
export const walletRoutes: FastifyPluginAsyncZod<{ service: WalletService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/wallet', { schema: { response: { 200: walletResponse } } }, (request) => service.wallet(request.userId));

  // Clé d'idempotence obligatoire : un double appui ou une requête rejouée ne recharge qu'une fois.
  app.post(
    '/wallet/topups',
    {
      schema: { body: topupBody, headers: topupHeaders, response: { 201: topupResponse } },
      config: { rateLimit: { max: 10, timeWindow: '1 hour' } },
    },
    async (request, reply) => {
      const result = await service.topup(request.userId, request.body.amountCents, request.headers['idempotency-key']);
      return reply.code(201).send(result);
    },
  );

  return Promise.resolve();
};
