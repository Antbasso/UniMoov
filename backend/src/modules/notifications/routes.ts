import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { deviceBody, deviceDeleteBody, preferencesBody, preferencesResponse } from './schema.js';
import type { NotificationService } from './service.js';

/** Appareils et préférences de notification (docs/api.md) ; uniquement les siens. */
export const notificationRoutes: FastifyPluginAsyncZod<{ service: NotificationService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.post(
    '/devices',
    { schema: { body: deviceBody, response: { 204: z.null() } }, config: { rateLimit: { max: 20, timeWindow: '1 hour' } } },
    async (request, reply) => {
      await service.registerDevice(request.userId, request.body.platform, request.body.pushToken);
      return reply.code(204).send(null);
    },
  );

  // À la déconnexion : l'appareil ne reçoit plus les notifications de ce compte.
  app.delete('/devices', { schema: { body: deviceDeleteBody, response: { 204: z.null() } } }, async (request, reply) => {
    await service.unregisterDevice(request.userId, request.body.pushToken);
    return reply.code(204).send(null);
  });

  app.get('/me/notification-preferences', { schema: { response: { 200: preferencesResponse } } }, (request) =>
    service.preferences(request.userId),
  );

  app.put(
    '/me/notification-preferences',
    { schema: { body: preferencesBody, response: { 200: preferencesResponse } } },
    (request) => service.setPreferences(request.userId, request.body),
  );

  return Promise.resolve();
};
