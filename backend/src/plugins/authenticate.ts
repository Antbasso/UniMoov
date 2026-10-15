import fastifyJwt from '@fastify/jwt';
import type { FastifyReply, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';
import { AppError } from '../shared/errors.js';

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { sub: string };
    user: { sub: string };
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    /** preHandler : exige un JWT d'accès valide et expose `request.userId`. */
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    userId: string;
  }
}

export const authenticatePlugin = fp<{ secret: string; accessTokenTtlSeconds: number }>(
  async (app, { secret, accessTokenTtlSeconds }) => {
    await app.register(fastifyJwt, {
      secret,
      sign: { algorithm: 'HS256', expiresIn: accessTokenTtlSeconds },
      verify: { algorithms: ['HS256'] },
    });
    app.decorateRequest('userId', '');
    app.decorate('authenticate', async (request: FastifyRequest) => {
      try {
        const payload = await request.jwtVerify<{ sub: string }>();
        request.userId = payload.sub;
      } catch {
        throw new AppError(401, 'unauthorized', 'Connexion requise');
      }
    });
  },
  { name: 'authenticate' },
);
