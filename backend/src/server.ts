import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDatabase } from './db/client.js';
import { startJobs } from './jobs.js';
import { BanGeocodingProvider } from './shared/geocoding/ban-geocoding-provider.js';
import { CachedGeocodingProvider } from './shared/geocoding/cached-geocoding-provider.js';
import { FakeGeocodingProvider } from './shared/geocoding/fake-geocoding-provider.js';
import { OrsRoutingProvider } from './shared/routing/ors-routing-provider.js';
import { FakePaymentProvider } from './shared/payments/payment-provider.js';
import { ConsoleMailProvider } from './shared/mail/console-mail-provider.js';

const config = loadConfig();
// Le logger n'existe qu'une fois l'app construite ; le pool en a besoin dès sa création.
let logIdleError: (error: Error) => void = () => undefined;
const database = createDatabase(config.DATABASE_URL, { onIdleError: (error) => logIdleError(error) });

const geocoding =
  config.GEOCODING_PROVIDER === 'fake'
    ? new FakeGeocodingProvider()
    : new CachedGeocodingProvider(new BanGeocodingProvider(config.GEOCODING_URL));

const app = await buildApp({
  config,
  pingDb: async () => {
    await database.pool.query('SELECT 1');
  },
  modules: {
    db: database.db,
    jwtSecret: config.JWT_SECRET,
    calendarKey: config.CALENDAR_ENCRYPTION_KEY,
    // Développement uniquement (refusé en production par la config).
    mail: new ConsoleMailProvider((line) => process.stdout.write(`${line}\n`)),
    geocoding,
    // Développement uniquement (refusé en production par la config) ; prestataire réel en M4b.
    payments: new FakePaymentProvider(),
    ...(config.ROUTING_PROVIDER === 'ors' && config.ORS_API_KEY
      ? { routing: new OrsRoutingProvider(config.ORS_API_KEY), routingDailyQuota: config.ROUTING_DAILY_QUOTA }
      : {}),
  },
});
logIdleError = (error) => app.log.error({ err: error }, 'idle database connection error');

const stopJobs =
  config.JOBS_ENABLED && app.services
    ? await startJobs(config.DATABASE_URL, app.services, app.log)
    : () => Promise.resolve();

const shutdown = async () => {
  await stopJobs();
  await app.close();
  await database.close();
  process.exit(0);
};
process.once('SIGINT', () => void shutdown());
process.once('SIGTERM', () => void shutdown());

await app.listen({ host: config.HOST, port: config.PORT });
