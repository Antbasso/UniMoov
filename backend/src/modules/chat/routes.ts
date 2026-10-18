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
  messageParams,
  messagesResponse,
  carpoolBody,
  sendBody,
} from './schema.js';
import type { ChatService } from './service.js';

const PING_INTERVAL_MS = 30_000;

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
      let exp: number;
      try {
        const payload = app.jwt.verify<{ sub: string; exp: number }>(request.query.token);
        if (!(await isActiveUser(payload.sub))) throw new Error('inactive');
        userId = payload.sub;
        exp = payload.exp;
      } catch {
        socket.close(4401, 'unauthorized');
        return;
      }
      if (closed) return;
      hub.add(userId, socket);
      // Jeton expiré : on ferme, le client se reconnecte avec un jeton renouvelé.
      const expiry = setTimeout(() => socket.close(4401, 'token_expired'), Math.max(0, exp * 1000 - Date.now()));
      // Ping toutes les 30 s : un téléphone en veille ou une connexion coupée sans fermeture
      // n'est plus compté « en ligne » (sinon pas de push) et ne reste pas en mémoire.
      let alive = true;
      socket.on('pong', () => {
        alive = true;
      });
      const heartbeat = setInterval(() => {
        if (!alive) {
          socket.terminate();
          return;
        }
        alive = false;
        socket.ping();
      }, PING_INTERVAL_MS);
      socket.on('close', () => {
        clearTimeout(expiry);
        clearInterval(heartbeat);
        hub.remove(userId, socket);
      });
      socket.send(JSON.stringify({ type: 'ready' }));
    },
  );
  return Promise.resolve();
};

/** Messagerie (docs/api.md) ; seuls les membres d'une conversation la voient. */
export const chatRoutes: FastifyPluginAsyncZod<{ service: ChatService }> = (api, { service }) => {
  api.addHook('preHandler', api.authenticate);

  // Proposition de covoiturage dans un groupe ou une conversation privée (texte écrit par le serveur).
  api.post(
    '/conversations/:id/carpool',
    { schema: { params: conversationParams, body: carpoolBody, response: { 201: message } }, config: { rateLimit: { max: 20, timeWindow: '1 hour' } } },
    async (request, reply) => reply.code(201).send(await service.postCarpool(request.userId, request.params.id, request.body)),
  );

  api.post(
    '/conversations/:id/messages/:messageId/carpool/accept',
    { schema: { params: messageParams, response: { 200: message } }, config: { rateLimit: { max: 30, timeWindow: '1 hour' } } },
    (request) => service.acceptCarpool(request.userId, request.params.id, request.params.messageId),
  );

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
        request.query.before ? { at: new Date(request.query.before), id: request.query.beforeId ?? null } : null,
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
