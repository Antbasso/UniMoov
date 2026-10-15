import { fileURLToPath, pathToFileURL } from 'node:url';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { createDatabase } from './client.js';

/** Dossier des migrations SQL versionnées (même chemin depuis src/db et dist/db). */
export const migrationsFolder = fileURLToPath(new URL('../../migrations', import.meta.url));

export async function runMigrations(databaseUrl: string): Promise<void> {
  const database = createDatabase(databaseUrl);
  try {
    await migrate(database.db, { migrationsFolder });
  } finally {
    await database.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL manquant');
  await runMigrations(url);
  console.log('Migrations appliquées');
}
