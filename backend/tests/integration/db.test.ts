import { sql } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { createDatabase, type Database } from '../../src/db/client.js';
import { runMigrations } from '../../src/db/migrate.js';
import { runSeed } from '../../src/db/seed.js';
import { seedUsers } from '../../src/db/seed-data.js';
import { prepareTestDatabase } from './test-database.js';

const url = process.env.TEST_DATABASE_URL;
if (!url) throw new Error('TEST_DATABASE_URL requis pour les tests d’intégration (voir README)');

let database: Database;

beforeAll(async () => {
  await prepareTestDatabase(url);
  database = createDatabase(url);
  await runMigrations(url);
});

afterAll(async () => {
  await database.close();
});

describe('protection de la base de test', () => {
  it('refuse une base dont le nom ne finit pas par _test', async () => {
    const devUrl = new URL(url);
    devUrl.pathname = '/unimoov';
    await expect(prepareTestDatabase(devUrl.toString())).rejects.toThrow(/_test/);
  });
});

describe('migrations et seed', () => {
  it('active PostGIS', async () => {
    const { rows } = await database.pool.query<{ v: string }>('SELECT postgis_version() AS v');
    expect(rows[0]?.v).toMatch(/^3\./);
  });

  it('ré-appliquer les migrations ne change rien', async () => {
    await expect(runMigrations(url)).resolves.toBeUndefined();
  });

  it('insère les paramètres par défaut et le campus pilote', async () => {
    const { rows } = await database.pool.query<{ value: number }>(
      "SELECT value FROM app_settings WHERE key = 'wallet.minTopupCents'",
    );
    expect(rows[0]?.value).toBe(1000);
    const campuses = await database.db.execute(sql`SELECT count(*)::int AS n FROM campuses`);
    expect(campuses.rows[0]).toEqual({ n: 1 });
  });

  it('le seed est idempotent et place les étudiants près du campus', async () => {
    await runSeed(database.db);
    await runSeed(database.db);
    const { rows } = await database.pool.query<{ n: number; far: number; sectors: number }>(`
      SELECT count(*)::int AS n,
             count(*) FILTER (WHERE ST_Distance(u.home_location, c.location) > 30000)::int AS far,
             count(home_sector)::int AS sectors
      FROM users u JOIN campuses c ON c.id = u.campus_id`);
    expect(rows[0]).toEqual({ n: seedUsers.length, far: 0, sectors: seedUsers.length });
    const vehicles = await database.pool.query<{ n: number }>('SELECT count(*)::int AS n FROM vehicles');
    expect(vehicles.rows[0]?.n).toBe(seedUsers.filter((u) => u.vehicle).length);
  });

  it('GET /health répond 200 avec une vraie base', async () => {
    const app = await buildApp({
      config: { LOG_LEVEL: 'silent' },
      pingDb: async () => {
        await database.pool.query('SELECT 1');
      },
    });
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(200);
    await app.close();
  });
});
