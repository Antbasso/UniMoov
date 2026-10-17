import type {} from '@fastify/websocket';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import type { UserHub } from './hub.js';
import {
  contactsResponse,
  conversation,
  conversationParams,
  conversationsResponse,
  createBody,
  message,
  messagesQuery,
  messagesResponse,
  sendBody,
} from './schema.js';
import type { ChatService } from './service.js';

/** Socket utilisateur `GET /ws/me?token=<jwt>` (docs/api.md) : messages en direct. Jeton jamais journalisé. */
export const userSocketRoutes: FastifyPluginAsyncZod<{
  hub: UserHub;
  isActiveUser: (userId: string) => Promise<boolean>;
}> = (app, { hub, isActiveUser }) => {
  app.get(
    '/ws/me',
    { websocket: true, schema: { querystring: z.object({ token: z.string().min(1) }) } },
    async (socket, request) => {
      let closed = false;
      socket.on('close', () => {
        closed = true;
      });
      // Les clients n'envoient rien sur ce socket : tout message entrant est ignoré.
      socket.on('message', () => undefined);
      let userId: string;
      try {
        const payload = app.jwt.verify<{ sub: string }>(request.query.token);
        if (!(await isActiveUser(payload.sub))) throw new Error('inactive');
        userId = payload.sub;
      } catch {
        socket.close(4401, 'unauthorized');
        return;
      }
      if (closed) return;
      hub.add(userId, socket);
      socket.on('close', () => hub.remove(userId, socket));
      socket.send(JSON.stringify({ type: 'ready' }));
    },
  );
  return Promise.resolve();
};

/** Messagerie (docs/api.md) ; seuls les membres d'une conversation la voient. */
export const chatRoutes: FastifyPluginAsyncZod<{ service: ChatService }> = (api, { service }) => {
  api.addHook('preHandler', api.authenticate);

  api.get('/conversations', { schema: { response: { 200: conversationsResponse } } }, async (request) => ({
    conversations: await service.list(request.userId),
  }));

  api.get('/rides/:id/conversation', { schema: { params: conversationParams, response: { 200: conversation } } }, (request) =>
    service.forRide(request.userId, request.params.id),
  );

  api.get('/contacts', { schema: { response: { 200: contactsResponse } } }, async (request) => ({
    contacts: await service.contacts(request.userId),
  }));

  api.post(
    '/conversations',
    { schema: { body: createBody, response: { 201: conversation } }, config: { rateLimit: { max: 20, timeWindow: '1 hour' } } },
    async (request, reply) => reply.code(201).send(await service.create(request.userId, request.body)),
  );

  api.get('/conversations/:id', { schema: { params: conversationParams, response: { 200: conversation } } }, (request) =>
    service.get(request.userId, request.params.id),
  );

  api.get(
    '/conversations/:id/messages',
    { schema: { params: conversationParams, querystring: messagesQuery, response: { 200: messagesResponse } } },
    async (request) => ({
      messages: await service.messages(
        request.userId,
        request.params.id,
        request.query.before ? new Date(request.query.before) : null,
        request.query.limit,
      ),
    }),
  );

  api.post(
    '/conversations/:id/messages',
    {
      schema: { params: conversationParams, body: sendBody, response: { 201: message } },
      config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    },
    async (request, reply) => reply.code(201).send(await service.send(request.userId, request.params.id, request.body.body)),
  );

  api.post('/conversations/:id/read', { schema: { params: conversationParams, response: { 204: z.null() } } }, async (request, reply) => {
    await service.markRead(request.userId, request.params.id);
    return reply.code(204).send(null);
  });

  api.delete(
    '/conversations/:id/members/me',
    { schema: { params: conversationParams, response: { 204: z.null() } } },
    async (request, reply) => {
      await service.leave(request.userId, request.params.id);
      return reply.code(204).send(null);
    },
  );

  return Promise.resolve();
};
