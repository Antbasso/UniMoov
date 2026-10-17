import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import Fastify, { type FastifyInstance, type FastifyRequest } from 'fastify';
import {
  hasZodFastifySchemaValidationErrors,
  jsonSchemaTransform,
  serializerCompiler,
  validatorCompiler,
  type ZodTypeProvider,
} from 'fastify-type-provider-zod';
import type { Config } from './config.js';
import type { Db } from './db/client.js';
import { AccountRepo } from './modules/account/repo.js';
import { accountRoutes } from './modules/account/routes.js';
import { AccountService } from './modules/account/service.js';
import { AuthRepo } from './modules/auth/repo.js';
import { CalendarRepo } from './modules/calendar/repo.js';
import { calendarRoutes } from './modules/calendar/routes.js';
import { CalendarService } from './modules/calendar/service.js';
import { MatchingRepo } from './modules/matching/repo.js';
import { matchingRoutes } from './modules/matching/routes.js';
import { MatchingService } from './modules/matching/service.js';
import { authRoutes } from './modules/auth/routes.js';
import { AuthService } from './modules/auth/service.js';
import { AUTH_POLICY } from './modules/auth/policy.js';
import { healthRoutes } from './modules/health/routes.js';
import type { PingDb } from './modules/health/service.js';
import { PaymentsRepo } from './modules/payments/repo.js';
import { walletRoutes } from './modules/payments/routes.js';
import { WalletService } from './modules/payments/service.js';
import { RideLifecycle } from './modules/rides/lifecycle.js';
import { RidesRepo } from './modules/rides/repo.js';
import { TrackingHub } from './modules/tracking/hub.js';
import { trackingRoutes } from './modules/tracking/routes.js';
import { TrackingService } from './modules/tracking/service.js';
import { ridesRoutes } from './modules/rides/routes.js';
import { RidesService } from './modules/rides/service.js';
import { ProfileRepo } from './modules/profile/repo.js';
import { profileRoutes } from './modules/profile/routes.js';
import { ProfileService } from './modules/profile/service.js';
import { SettingsService } from './modules/settings/service.js';
import { TrustRepo } from './modules/trust/repo.js';
import { trustRoutes } from './modules/trust/routes.js';
import { TrustService } from './modules/trust/service.js';
import type { Notifier } from './shared/notifications/notifier.js';
import { LogPushProvider, type PushProvider } from './shared/push/push-provider.js';
import { UserHub } from './modules/chat/hub.js';
import { ChatRepo } from './modules/chat/repo.js';
import { chatRoutes, userSocketRoutes } from './modules/chat/routes.js';
import { ChatService } from './modules/chat/service.js';
import { NotificationsRepo } from './modules/notifications/repo.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { NotificationService } from './modules/notifications/service.js';
import { authenticatePlugin } from './plugins/authenticate.js';
import { SecretBox } from './shared/crypto.js';
import { AppError, errorBody } from './shared/errors.js';
import { fetchPublicText } from './shared/safe-fetch.js';
import type { GeocodingProvider } from './shared/geocoding/geocoding-provider.js';
import type { MailProvider } from './shared/mail/mail-provider.js';
import { EstimateRoutingProvider } from './shared/routing/estimate.js';
import { GuardedRoutingProvider } from './shared/routing/guarded-routing-provider.js';
import type { RoutingProvider } from './shared/routing/routing-provider.js';
import type { PaymentProvider } from './shared/payments/payment-provider.js';

declare module 'fastify' {
  interface FastifyInstance {
    /** Services utilisés par les tâches planifiées (présents si les modules sont montés). */
    services?: {
      calendar: CalendarService;
      matching: MatchingService;
      lifecycle: RideLifecycle;
      trust: TrustService;
      chat: ChatService;
      notifications: NotificationService;
    };
  }
}

/** Dépendances des modules métier ; absentes, seule la route /health est montée. */
export interface AppModules {
  db: Db;
  jwtSecret: string;
  mail: MailProvider;
  geocoding: GeocodingProvider;
  /** Clé AES-256 (base64) des liens d'agenda. */
  calendarKey: string;
  /** Fournisseur d'itinéraires (OpenRouteService) ; absent : estimation locale seulement. */
  routing?: RoutingProvider;
  /** Appels quotidiens autorisés au fournisseur (palier gratuit). */
  routingDailyQuota?: number;
  /** Prestataire de paiement (factice tant que l'équipe n'a pas fourni de compte). */
  payments: PaymentProvider;
  /** Envoi push (FCM) ; par défaut, journal seulement. */
  push?: PushProvider;
  /** Observateur de notifications supplémentaire (tests). */
  notifier?: Notifier;
  /** Lecture d'un lien ICS ; par défaut téléchargement protégé contre le SSRF. */
  fetchIcs?: (url: string) => Promise<string>;
  clock?: () => Date;
  /** Limites de débit (désactivables pour les tests d'intégration hors test dédié). */
  rateLimit?: boolean;
}

export interface AppDeps {
  config: Pick<Config, 'LOG_LEVEL'> & Partial<Pick<Config, 'TRUST_PROXY' | 'NODE_ENV'>>;
  pingDb: PingDb;
  /** Destination des journaux (stdout par défaut) ; injectable pour les tests. */
  logStream?: { write: (line: string) => void };
  modules?: AppModules;
}

export async function buildApp({ config, pingDb, logStream, modules }: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    // Derrière Caddy en production : l'IP réelle sert à la limite de débit, jamais aux journaux.
    trustProxy: config.TRUST_PROXY ?? false,
    logger: {
      level: config.LOG_LEVEL,
      ...(logStream ? { stream: logStream } : {}),
      // Aucune donnée personnelle ni secret dans les journaux (AGENTS.md) : ni IP, ni en-têtes,
      // ni paramètres d'URL (jetons, coordonnées).
      serializers: {
        req: (request: FastifyRequest) => ({
          method: request.method,
          route: request.routeOptions.url ?? 'unknown',
        }),
        // Sans les champs annexes (le `detail` de PostgreSQL recopie les valeurs fautives).
        err: logError,
      },
    },
  }).withTypeProvider<ZodTypeProvider>();

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  app.setErrorHandler((error, request, reply) => {
    if (hasZodFastifySchemaValidationErrors(error)) {
      return reply.code(400).send(errorBody('validation_error', 'Requête invalide'));
    }
    if (error instanceof AppError) {
      return reply.code(error.statusCode).send(errorBody(error.code, error.message));
    }
    // Erreurs client levées par Fastify et ses plugins (JSON mal formé, limite de débit…).
    const status = (error as { statusCode?: unknown }).statusCode;
    if (typeof status === 'number' && status >= 400 && status < 500) {
      const { code, message } = clientError(status);
      return reply.code(status).send(errorBody(code, message));
    }
    request.log.error({ err: error }, 'unhandled error');
    return reply.code(500).send(errorBody('internal_error', 'Erreur interne'));
  });

  app.setNotFoundHandler((_request, reply) =>
    reply.code(404).send(errorBody('not_found', 'Ressource introuvable')),
  );

  await app.register(rateLimit, {
    global: false,
    ...(modules?.rateLimit === false ? { allowList: () => true } : {}),
  });

  if (config.NODE_ENV === 'development') {
    // Contrat OpenAPI généré depuis les schémas Zod, publié en développement uniquement.
    await app.register(swagger, {
      openapi: { info: { title: 'Uni-Moov API', version: '1' } },
      transform: jsonSchemaTransform,
    });
    await app.register(swaggerUi, { routePrefix: '/docs' });
  }

  await app.register(healthRoutes, { pingDb });

  if (modules) {
    const clock = modules.clock ?? (() => new Date());
    const authRepo = new AuthRepo(modules.db);
    await app.register(authenticatePlugin, {
      secret: modules.jwtSecret,
      accessTokenTtlSeconds: AUTH_POLICY.accessTokenTtlSeconds,
      isActiveUser: (userId) => authRepo.isActiveUser(userId),
    });
    const settings = new SettingsService(modules.db);
    const authService = new AuthService({
      repo: authRepo,
      mail: modules.mail,
      settings,
      clock,
      secret: modules.jwtSecret,
      signAccessToken: (userId) => app.jwt.sign({ sub: userId }),
    });
    const estimate = new EstimateRoutingProvider(async () => ({
      roadFactor: await settings.get('matching.roadFactor'),
      avgSpeedKmh: await settings.get('matching.avgSpeedKmh'),
    }));
    const routing = modules.routing
      ? new GuardedRoutingProvider(modules.routing, estimate, {
          dailyQuota: modules.routingDailyQuota ?? 2000,
          onEvent: (event) => app.log.warn({ event }, 'routing provider'),
        })
      : estimate;
    const ridesRepo = new RidesRepo(modules.db);
    const ridesService = new RidesService(ridesRepo, routing, settings, clock, Boolean(modules.routing));
    const wallet = new WalletService(new PaymentsRepo(modules.db), modules.payments, settings);
    const hub = new TrackingHub();
    const trust = new TrustService(new TrustRepo(modules.db), settings, modules.mail, clock);
    const notifications = new NotificationService(
      new NotificationsRepo(modules.db),
      modules.push ?? new LogPushProvider((data, message) => app.log.info(data, message)),
      settings,
      clock,
    );
    const extra = modules.notifier;
    const notifier: Notifier = extra
      ? { notify: async (userIds, event) => void (await Promise.all([extra.notify(userIds, event), notifications.notify(userIds, event)])) }
      : notifications;
    const userHub = new UserHub();
    const chat = new ChatService(new ChatRepo(modules.db), userHub, settings, notifier, clock);
    // Le suivi relit l'état d'un trajet quand le cycle de vie le modifie (appel différé).
    const lifecycle = new RideLifecycle(ridesRepo, ridesService, wallet, hub, settings, clock, (rideId) =>
      tracking.invalidate(rideId),
      trust,
    );
    const tracking = new TrackingService(hub, lifecycle, ridesRepo, settings, () => clock().getTime());
    const matchingService = new MatchingService(
      new MatchingRepo(modules.db),
      settings,
      clock,
      async (rideId) => {
        // Chat de trajet créé à la confirmation, membres suivis à chaque acceptation ou annulation ;
        // indépendant du calcul d'itinéraire (appel externe qui peut échouer).
        await chat.syncRideChat(rideId).catch((err: unknown) => app.log.error({ err }, 'ride chat sync'));
        await ridesService.onRideChanged(rideId);
      },
      trust,
      notifier,
    );
    const profileService = new ProfileService(new ProfileRepo(modules.db), modules.geocoding, clock, async (userId) => {
      await matchingService.onProfileChanged(userId);
      // Adresse ou véhicule modifié : tracé, heures et prix des trajets confirmés à jour.
      await ridesService.onUserChanged(userId);
    });
    const calendarService = new CalendarService({
      repo: new CalendarRepo(modules.db),
      box: new SecretBox(modules.calendarKey),
      fetchIcs: modules.fetchIcs ?? ((url) => fetchPublicText(url)),
      settings,
      clock,
      onScheduleChanged: (userId, days) => matchingService.onScheduleChanged(userId, days),
    });
    const accountService = new AccountService({
      repo: new AccountRepo(modules.db),
      checkPassword: (userId, password) => authService.checkPassword(userId, password),
      cancelRide: (userId, rideId) => matchingService.cancel(userId, rideId),
      declineRide: (userId, rideId) => matchingService.decline(userId, rideId),
      disconnect: (userId) => userHub.disconnect(userId),
      clock,
      log: (data, message) => app.log.error(data, message),
    });
    app.decorate('services', { calendar: calendarService, matching: matchingService, lifecycle, trust, chat, notifications });
    await app.register(websocket, { options: { maxPayload: 4096 } });

    await app.register(
      async (api) => {
        await api.register(authRoutes, { service: authService });
        await api.register(profileRoutes, { service: profileService });
        await api.register(accountRoutes, { service: accountService });
        await api.register(calendarRoutes, { service: calendarService });
        await api.register(matchingRoutes, { service: matchingService });
        await api.register(ridesRoutes, { service: ridesService, lifecycle });
        await api.register(walletRoutes, { service: wallet });
        await api.register(trustRoutes, { service: trust });
        await api.register(chatRoutes, { service: chat });
        await api.register(notificationRoutes, { service: notifications });
        await api.register(userSocketRoutes, { hub: userHub, isActiveUser: (userId) => authRepo.isActiveUser(userId) });
        await api.register(trackingRoutes, {
          service: tracking,
          isActiveUser: (userId) => authRepo.isActiveUser(userId),
        });
      },
      { prefix: '/api/v1' },
    );
  }

  return app;
}

/** Erreur réduite au type, au code, au message et à la pile. */
export function logError(error: unknown): { type: string; message: string; stack: string; code?: string } {
  if (!(error instanceof Error)) return { type: typeof error, message: '', stack: '' };
  const code = (error as { code?: unknown }).code;
  return {
    type: error.name,
    message: error.message,
    stack: error.stack ?? '',
    ...(typeof code === 'string' ? { code } : {}),
  };
}

function clientError(status: number): { code: string; message: string } {
  switch (status) {
    case 400:
      return { code: 'bad_request', message: 'Requête invalide' };
    case 413:
      return { code: 'payload_too_large', message: 'Requête invalide' };
    case 415:
      return { code: 'unsupported_media_type', message: 'Requête invalide' };
    case 429:
      return { code: 'rate_limited', message: 'Trop de tentatives, réessaie dans quelques minutes' };
    default:
      return { code: `http_${status}`, message: 'Requête invalide' };
  }
}
