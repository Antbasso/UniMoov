import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { achievementsResponse, leaderboardResponse } from './schema.js';
import type { GamificationService } from './service.js';

/** Gamification (docs/api.md) : mes points, niveau, badges et impact ; classement du campus. */
export const gamificationRoutes: FastifyPluginAsyncZod<{ service: GamificationService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/me/achievements', { schema: { response: { 200: achievementsResponse } } }, (request) =>
    service.achievements(request.userId),
  );

  app.get('/leaderboard', { schema: { response: { 200: leaderboardResponse } }, config: { rateLimit: { max: 60, timeWindow: '1 minute' } } }, (request) =>
    service.leaderboard(request.userId),
  );

  return Promise.resolve();
};
