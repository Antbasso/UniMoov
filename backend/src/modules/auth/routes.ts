import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { loginBody, refreshBody, requestCodeBody, tokensResponse, verifyBody } from './schema.js';
import type { AuthService } from './service.js';

/** Limites par adresse IP (réelle derrière Caddy via TRUST_PROXY). */
const limit = (max: number, timeWindow: string) => ({ rateLimit: { max, timeWindow } });

export const authRoutes: FastifyPluginAsyncZod<{ service: AuthService }> = (app, { service }) => {
  app.post(
    '/auth/signup/request-code',
    { schema: { body: requestCodeBody, response: { 202: z.null() } }, config: limit(5, '15 minutes') },
    async (request, reply) => {
      await service.requestSignupCode(request.body.universityEmail);
      return reply.code(202).send(null);
    },
  );

  app.post(
    '/auth/signup/verify',
    { schema: { body: verifyBody, response: { 201: tokensResponse } }, config: limit(10, '15 minutes') },
    async (request, reply) => reply.code(201).send(await service.verifySignup(request.body)),
  );

  app.post(
    '/auth/login',
    { schema: { body: loginBody, response: { 200: tokensResponse } }, config: limit(10, '15 minutes') },
    async (request) => service.login(request.body),
  );

  app.post(
    '/auth/refresh',
    { schema: { body: refreshBody, response: { 200: tokensResponse } }, config: limit(30, '1 minute') },
    async (request) => service.refresh(request.body.refreshToken),
  );

  app.post(
    '/auth/logout',
    { schema: { body: refreshBody, response: { 204: z.null() } }, config: limit(30, '1 minute') },
    async (request, reply) => {
      await service.logout(request.body.refreshToken);
      return reply.code(204).send(null);
    },
  );

  return Promise.resolve();
};
