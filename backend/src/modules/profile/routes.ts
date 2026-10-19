import { PHOTO_MAX_BYTES } from '../../shared/images.js';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  addressBody,
  addressQuery,
  addressSuggestions,
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
import { AppError } from '../../shared/errors.js';
import type { ProfileService } from './service.js';


/** Toutes les routes exigent un JWT ; l'utilisateur ne touche qu'à son propre profil. */
export const profileRoutes: FastifyPluginAsyncZod<{ service: ProfileService }> = (app, { service }) => {
  app.addHook('preHandler', app.authenticate);

  app.get('/me', { schema: { response: { 200: meResponse } } }, (request) => service.getMe(request.userId));

  app.patch('/me', { config: { rateLimit: { max: 20, timeWindow: '1 hour' } }, schema: { body: patchMeBody, response: { 200: meResponse } } }, (request) =>
    service.updateNames(request.userId, request.body),
  );

  // Autocomplétion de l'adresse (un appel par frappe, après une pause côté app).
  app.get(
    '/addresses',
    { config: { rateLimit: { max: 120, timeWindow: '1 hour' } }, schema: { querystring: addressQuery, response: { 200: addressSuggestions } } },
    async (request) => ({ suggestions: await service.suggestAddresses(request.query.q) }),
  );

  app.put('/me/address', { config: { rateLimit: { max: 10, timeWindow: '1 hour' } }, schema: { body: addressBody, response: { 200: meResponse } } }, (request) =>
    service.setAddress(request.userId, request.body.address),
  );

  app.put('/me/vehicle', { config: { rateLimit: { max: 20, timeWindow: '1 hour' } }, schema: { body: vehicleSchema, response: { 200: meResponse } } }, (request) =>
    service.setVehicle(request.userId, request.body),
  );

  app.delete('/me/vehicle', { schema: { response: { 204: z.null() } } }, async (request, reply) => {
    await service.removeVehicle(request.userId);
    return reply.code(204).send(null);
  });

  app.patch('/me/preferences', { config: { rateLimit: { max: 30, timeWindow: '1 hour' } }, schema: { body: preferencesBody, response: { 200: meResponse } } }, (request) =>
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

  app.post('/me/pauses', { config: { rateLimit: { max: 20, timeWindow: '1 hour' } }, schema: { body: pauseBody, response: { 201: pauseSchema } } }, async (request, reply) =>
    reply.code(201).send(await service.addPause(request.userId, request.body)),
  );

  app.delete('/me/pauses/:id', { schema: { params: idParams, response: { 204: z.null() } } }, async (request, reply) => {
    await service.removePause(request.userId, request.params.id);
    return reply.code(204).send(null);
  });

  app.get('/users/:id/public', { schema: { params: idParams, response: { 200: publicProfileResponse } } }, (request) =>
    service.getPublicProfile(request.userId, request.params.id),
  );

  // Photo de profil : corps brut JPEG ou PNG, 600 Ko au plus (l'app la réduit avant l'envoi).
  app.addContentTypeParser(['image/jpeg', 'image/png'], { parseAs: 'buffer', bodyLimit: PHOTO_MAX_BYTES }, (_request, body, done) => {
    done(null, body);
  });

  app.put(
    '/me/photo',
    { bodyLimit: PHOTO_MAX_BYTES, config: { rateLimit: { max: 10, timeWindow: '1 hour' } }, schema: { response: { 200: meResponse } } },
    (request) => {
      const contentType = request.headers['content-type']?.split(';')[0]?.trim() ?? '';
      if (!Buffer.isBuffer(request.body)) throw new AppError(415, 'photo_invalid', 'Choisis une photo JPEG ou PNG');
      return service.setPhoto(request.userId, contentType, request.body);
    },
  );

  app.delete('/me/photo', { schema: { response: { 204: z.null() } } }, async (request, reply) => {
    await service.removePhoto(request.userId);
    return reply.code(204).send(null);
  });

  app.get('/users/:id/photo', { schema: { params: idParams } }, async (request, reply) => {
    const photo = await service.getPhoto(request.userId, request.params.id);
    // L'URL change avec la photo : l'app peut la garder longtemps.
    return reply.header('cache-control', 'private, max-age=604800').type(photo.contentType).send(photo.data);
  });

  return Promise.resolve();
};
