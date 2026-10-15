import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  addressBody,
  idParams,
  meResponse,
  onboardingBody,
  onboardingParams,
  patchMeBody,
  pauseBody,
  pauseSchema,
  pausesResponse,
  preferencesBody,
  publicProfileResponse,
  vehicleSchema,
} from './schema.js';
import type { ProfileService } from './service.js';

/** Toutes les routes exigent un JWT ; l'utilisateur ne touche qu'à son propre profil. */
export const profileRoutes: FastifyPluginAsyncZod<{ service: ProfileService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/me', { schema: { response: { 200: meResponse } } }, (request) => service.getMe(request.userId));

  app.patch('/me', { schema: { body: patchMeBody, response: { 200: meResponse } } }, (request) =>
    service.updateNames(request.userId, request.body),
  );

  app.put('/me/address', { schema: { body: addressBody, response: { 200: meResponse } } }, (request) =>
    service.setAddress(request.userId, request.body.address),
  );

  app.put('/me/vehicle', { schema: { body: vehicleSchema, response: { 200: meResponse } } }, (request) =>
    service.setVehicle(request.userId, request.body),
  );

  app.delete('/me/vehicle', { schema: { response: { 204: z.null() } } }, async (request, reply) => {
    await service.removeVehicle(request.userId);
    return reply.code(204).send(null);
  });

  app.patch('/me/preferences', { schema: { body: preferencesBody, response: { 200: meResponse } } }, (request) =>
    service.setPreferences(request.userId, request.body),
  );

  app.put(
    '/me/onboarding/:step',
    { schema: { params: onboardingParams, body: onboardingBody, response: { 200: meResponse } } },
    (request) => service.setOnboardingStep(request.userId, request.params.step, request.body.status),
  );

  app.get('/me/pauses', { schema: { response: { 200: pausesResponse } } }, async (request) => ({
    pauses: await service.listPauses(request.userId),
  }));

  app.post('/me/pauses', { schema: { body: pauseBody, response: { 201: pauseSchema } } }, async (request, reply) =>
    reply.code(201).send(await service.addPause(request.userId, request.body)),
  );

  app.delete('/me/pauses/:id', { schema: { params: idParams, response: { 204: z.null() } } }, async (request, reply) => {
    await service.removePause(request.userId, request.params.id);
    return reply.code(204).send(null);
  });

  app.get('/users/:id/public', { schema: { params: idParams, response: { 200: publicProfileResponse } } }, (request) =>
    service.getPublicProfile(request.params.id),
  );

  return Promise.resolve();
};
