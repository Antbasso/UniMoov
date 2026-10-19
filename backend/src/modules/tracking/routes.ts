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
      const rideId = request.params.rideId;
      // Écoute posée tout de suite : les messages reçus pendant les vérifications sont gardés,
      // puis traités dans l'ordre ; toute erreur est journalisée, jamais remontée au processus.
      const pending: string[] = [];
      let client: Awaited<ReturnType<TrackingService['connect']>> = null;
      let closed = false;
      let chain = Promise.resolve();
      const handle = (c: NonNullable<typeof client>, text: string) => {
        chain = chain
          .then(() => service.onMessage(rideId, c, text))
          .catch((err: unknown) => request.log.error({ err }, 'tracking message'));
      };
      socket.on('message', (data: Buffer) => {
        const text = data.toString();
        if (client) handle(client, text);
        else if (pending.length < 20) pending.push(text);
      });
      socket.on('close', () => {
        closed = true;
        if (client) service.disconnect(rideId, client);
      });

      let userId: string;
      let exp: number;
      try {
        const payload = app.jwt.verify<{ sub: string; exp: number }>(request.query.token);
        if (!(await isActiveUser(payload.sub))) throw new Error('inactive');
        userId = payload.sub;
        exp = payload.exp;
      } catch {
        socket.close(WS_CLOSE.unauthorized, 'unauthorized');
        return;
      }
      client = await service.connect(rideId, userId, socket);
      if (!client) return;
      // Fermé pendant la vérification : on ne laisse pas une connexion morte dans la salle.
      if (closed) {
        service.disconnect(rideId, client);
        return;
      }
      // Jeton expiré : on ferme, le client se reconnecte avec un jeton renouvelé (comme /ws/me).
      const expiry = setTimeout(() => socket.close(WS_CLOSE.unauthorized, 'token_expired'), Math.max(0, exp * 1000 - Date.now()));
      socket.on('close', () => clearTimeout(expiry));
      for (const text of pending.splice(0)) handle(client, text);
    },
  );
  return Promise.resolve();
};
