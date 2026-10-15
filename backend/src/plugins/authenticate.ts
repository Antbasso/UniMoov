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

export const authenticatePlugin = fp<{
  secret: string;
  accessTokenTtlSeconds: number;
  /** Compte existant et non supprimé : un JWT encore valide ne survit pas à la suppression. */
  isActiveUser: (userId: string) => Promise<boolean>;
}>(
  async (app, { secret, accessTokenTtlSeconds, isActiveUser }) => {
    await app.register(fastifyJwt, {
      secret,
      sign: { algorithm: 'HS256', expiresIn: accessTokenTtlSeconds },
      verify: { algorithms: ['HS256'] },
    });
    app.decorateRequest('userId', '');
    app.decorate('authenticate', async (request: FastifyRequest) => {
      let userId: string;
      try {
        userId = (await request.jwtVerify<{ sub: string }>()).sub;
      } catch {
        throw new AppError(401, 'unauthorized', 'Connexion requise');
      }
      if (!(await isActiveUser(userId))) throw new AppError(401, 'unauthorized', 'Connexion requise');
      request.userId = userId;
    });
  },
  { name: 'authenticate' },
);
