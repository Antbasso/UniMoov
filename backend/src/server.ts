import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDatabase } from './db/client.js';

const config = loadConfig();
// Le logger n'existe qu'une fois l'app construite ; le pool en a besoin dès sa création.
let logIdleError: (error: Error) => void = () => undefined;
const database = createDatabase(config.DATABASE_URL, { onIdleError: (error) => logIdleError(error) });
const app = await buildApp({
  config,
  pingDb: async () => {
    await database.pool.query('SELECT 1');
  },
});
logIdleError = (error) => app.log.error({ err: error }, 'idle database connection error');

const shutdown = async () => {
  await app.close();
  await database.close();
  process.exit(0);
};
process.once('SIGINT', () => void shutdown());
process.once('SIGTERM', () => void shutdown());

await app.listen({ host: config.HOST, port: config.PORT });
