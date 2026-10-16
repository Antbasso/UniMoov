import type {} from '@fastify/websocket';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { WS_CLOSE } from './hub.js';
import type { TrackingService } from './service.js';

/**
 * WebSocket de suivi : `GET /ws/rides/{rideId}?token=<jwt>` (docs/api.md). Le jeton passe en
 * paramètre (les navigateurs et la plupart des clients n'envoient pas d'en-tête à l'upgrade) ;
 * il n'est jamais journalisé (sérialiseur de requête sans URL).
 */
export const trackingRoutes: FastifyPluginAsyncZod<{
  service: TrackingService;
  isActiveUser: (userId: string) => Promise<boolean>;
}> = (app, { service, isActiveUser }) => {
  app.get(
    '/ws/rides/:rideId',
    {
      websocket: true,
      schema: { params: z.object({ rideId: z.uuid() }), querystring: z.object({ token: z.string().min(1) }) },
    },
    async (socket, request) => {
      let userId: string;
      try {
        const payload = app.jwt.verify<{ sub: string }>(request.query.token);
        if (!(await isActiveUser(payload.sub))) throw new Error('inactive');
        userId = payload.sub;
      } catch {
        socket.close(WS_CLOSE.unauthorized, 'unauthorized');
        return;
      }
      const rideId = request.params.rideId;
      // Messages reçus pendant la vérification d'accès : traités ensuite, dans l'ordre.
      const pending: string[] = [];
      let client: Awaited<ReturnType<TrackingService['connect']>> = null;
      let chain = Promise.resolve();
      socket.on('message', (data: Buffer) => {
        const text = data.toString();
        if (!client) {
          pending.push(text);
          return;
        }
        const c = client;
        chain = chain.then(() => service.onMessage(rideId, c, text)).catch((err: unknown) => request.log.error({ err }, 'tracking message'));
      });
      socket.on('close', () => {
        if (client) service.disconnect(rideId, client);
      });
      client = await service.connect(rideId, userId, socket);
      const c = client;
      if (c) for (const text of pending.splice(0)) chain = chain.then(() => service.onMessage(rideId, c, text));
    },
  );
  return Promise.resolve();
};
