import pg from 'pg';

/**
 * Prépare la base des tests d'intégration : refuse toute base dont le nom ne finit pas
 * par `_test` (protection contre l'effacement d'une base de dev), la crée si besoin
 * puis la remet à zéro.
 */
export async function prepareTestDatabase(url: string): Promise<void> {
  const target = new URL(url);
  const name = decodeURIComponent(target.pathname.replace(/^\//, ''));
  if (!/^[a-z0-9_]+_test$/.test(name)) {
    throw new Error(`Base de test refusée : « ${name} » doit finir par _test`);
  }

  const admin = new URL(url);
  admin.pathname = '/postgres';
  const adminClient = new pg.Client({ connectionString: admin.toString() });
  await adminClient.connect();
  try {
    const { rowCount } = await adminClient.query('SELECT 1 FROM pg_database WHERE datname = $1', [name]);
    // Nom validé par l'expression ci-dessus : pas d'injection possible.
    if (rowCount === 0) await adminClient.query(`CREATE DATABASE ${name}`);
  } finally {
    await adminClient.end();
  }

  const client = new pg.Client({ connectionString: url });
  await client.connect();
  try {
    await client.query(
      'DROP SCHEMA IF EXISTS public CASCADE; DROP SCHEMA IF EXISTS drizzle CASCADE; CREATE SCHEMA public;',
    );
  } finally {
    await client.end();
  }
}
