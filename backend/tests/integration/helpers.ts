import type { RoutingProvider } from '../../src/shared/routing/routing-provider.js';
import type { FastifyInstance } from 'fastify';
import { expect } from 'vitest';
import { buildApp } from '../../src/app.js';
import { createDatabase, type Database } from '../../src/db/client.js';
import { runMigrations } from '../../src/db/migrate.js';
import { FakeGeocodingProvider } from '../../src/shared/geocoding/fake-geocoding-provider.js';
import { MemoryMailProvider } from '../../src/shared/mail/memory-mail-provider.js';
import { MemoryNotifier } from '../../src/shared/notifications/notifier.js';
import { MemoryPushProvider } from '../../src/shared/push/push-provider.js';
import { FakePaymentProvider } from '../../src/shared/payments/payment-provider.js';
import { FetchFailedError } from '../../src/shared/safe-fetch.js';
import { prepareTestDatabase } from './test-database.js';

export const testDatabaseUrl = (): string => {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL requis pour les tests d’intégration (voir README)');
  return url;
};

export interface TestContext {
  app: FastifyInstance;
  database: Database;
  mail: MemoryMailProvider;
  geocoding: FakeGeocodingProvider;
  payments: FakePaymentProvider;
  notifier: MemoryNotifier;
  push: MemoryPushProvider;
  /** Faux agendas ICS servis par URL (aucun accès réseau dans les tests). */
  icsFeeds: Map<string, string>;
  /** Horloge des services (codes, pauses) ; avance avec `advance`. */
  clock: { now: Date; advance: (ms: number) => void };
  close: () => Promise<void>;
}

/** Base remise à zéro puis migrée, app complète avec fournisseurs factices. */
export async function setupTestContext(
  start = new Date('2026-10-15T08:00:00Z'),
  { rateLimit = false, routing }: { rateLimit?: boolean; routing?: RoutingProvider } = {},
): Promise<TestContext> {
  const url = testDatabaseUrl();
  await prepareTestDatabase(url);
  await runMigrations(url);
  const database = createDatabase(url);
  // Scénarios écrits avec le détour estimé à vol d'oiseau seul : pas de temps fixe par arrêt
  // (couvert par les tests unitaires du matching).
  await database.pool.query(`UPDATE app_settings SET value = '0' WHERE key = 'matching.stopPenaltySeconds'`);
  const mail = new MemoryMailProvider();
  const geocoding = new FakeGeocodingProvider();
  const payments = new FakePaymentProvider();
  const notifier = new MemoryNotifier();
  const push = new MemoryPushProvider();
  const icsFeeds = new Map<string, string>();
  const clock = {
    now: start,
    advance(ms: number) {
      this.now = new Date(this.now.getTime() + ms);
    },
  };
  const app = await buildApp({
    config: { LOG_LEVEL: 'silent' },
    pingDb: async () => {
      await database.pool.query('SELECT 1');
    },
    modules: {
      db: database.db,
      jwtSecret: 'test-secret-'.padEnd(40, 'x'),
      calendarKey: Buffer.alloc(32, 3).toString('base64'),
      fetchIcs: (url) => {
        const feed = icsFeeds.get(url);
        return feed === undefined ? Promise.reject(new FetchFailedError('HTTP 404')) : Promise.resolve(feed);
      },
      mail,
      geocoding,
      payments,
      notifier,
      push,
      clock: () => clock.now,
      rateLimit,
      ...(routing ? { routing } : {}),
    },
  });
  return {
    app,
    database,
    mail,
    geocoding,
    payments,
    notifier,
    push,
    icsFeeds,
    clock,
    close: async () => {
      await app.close();
      await database.close();
    },
  };
}

export interface Tokens {
  accessToken: string;
  refreshToken: string;
}

export function codeFromMail(ctx: TestContext, email: string): string {
  const message = ctx.mail.lastTo(email);
  const code = /(\d{6})/.exec(message?.subject ?? '')?.[1];
  if (!code) throw new Error(`Aucun code envoyé à ${email}`);
  return code;
}

/** Inscription complète via l'API ; avance l'horloge pour respecter le délai entre deux codes. */
export async function signUp(
  ctx: TestContext,
  email: string,
  names = { firstName: 'Léa', lastName: 'Martin' },
  password = 'motdepasse-solide',
): Promise<Tokens> {
  const request = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup/request-code',
    payload: { universityEmail: email },
  });
  expect(request.statusCode).toBe(202);
  const verify = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup/verify',
    payload: { universityEmail: email, code: codeFromMail(ctx, email), password, ...names },
  });
  expect(verify.statusCode).toBe(201);
  return verify.json<Tokens>();
}

export const bearer = (tokens: Tokens) => ({ authorization: `Bearer ${tokens.accessToken}` });
