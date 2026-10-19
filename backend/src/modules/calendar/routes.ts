import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  connectBody,
  connectionResponse,
  idParams,
  manualBody,
  manualResponse,
  scheduleQuery,
  scheduleResponse,
  syncResponse,
} from './schema.js';
import type { CalendarService } from './service.js';

/** Emploi du temps (docs/api.md, « Agenda ») ; le lien ICS n'est jamais renvoyé au client. */
export const calendarRoutes: FastifyPluginAsyncZod<{ service: CalendarService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);
  // Chaque lecture d’agenda télécharge un fichier externe : nombre d’appels limité.
  const syncLimit = { rateLimit: { max: 10, timeWindow: '1 hour' } };

  app.get('/calendar/connections', { schema: { response: { 200: connectionResponse } } }, async (request) => ({
    connection: await service.getConnection(request.userId),
  }));

  app.post(
    '/calendar/connections',
    { schema: { body: connectBody, response: { 201: syncResponse } }, config: syncLimit },
    async (request, reply) => reply.code(201).send(await service.connectIcs(request.userId, request.body.url)),
  );

  app.delete(
    '/calendar/connections/:id',
    { schema: { params: idParams, response: { 204: z.null() } } },
    async (request, reply) => {
      await service.disconnect(request.userId, request.params.id);
      return reply.code(204).send(null);
    },
  );

  app.post('/calendar/sync', { schema: { response: { 200: syncResponse } }, config: syncLimit }, (request) =>
    service.sync(request.userId),
  );

  app.get('/schedule/manual', { schema: { response: { 200: manualResponse } } }, async (request) => ({
    days: await service.getManual(request.userId),
  }));

  app.put('/schedule/manual', { config: { rateLimit: { max: 20, timeWindow: '1 hour' } }, schema: { body: manualBody, response: { 200: manualResponse } } }, (request) =>
    service.setManual(request.userId, request.body.days),
  );

  app.get('/schedule', { schema: { querystring: scheduleQuery, response: { 200: scheduleResponse } } }, async (request) => ({
    slots: await service.getSchedule(request.userId, request.query.from, request.query.to),
  }));

  return Promise.resolve();
};
