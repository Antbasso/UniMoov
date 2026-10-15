import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDatabase } from './db/client.js';

const config = loadConfig();
const database = createDatabase(config.DATABASE_URL);
const app = await buildApp({
  config,
  pingDb: async () => {
    await database.pool.query('SELECT 1');
  },
});

const shutdown = async () => {
  await app.close();
  await database.close();
  process.exit(0);
};
process.once('SIGINT', () => void shutdown());
process.once('SIGTERM', () => void shutdown());

await app.listen({ host: config.HOST, port: config.PORT });
