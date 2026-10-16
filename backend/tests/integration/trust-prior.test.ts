import { afterAll, beforeAll, expect, it } from 'vitest';
import { setupTestContext, signUp, type TestContext } from './helpers.js';

/** Le score de départ vient de `reliability.prior`, pas de la valeur par défaut de la colonne. */
let ctx: TestContext;

beforeAll(async () => {
  ctx = await setupTestContext();
  await ctx.app.ready();
});
afterAll(async () => {
  await ctx.close();
});

it('un nouvel inscrit part du score réglé dans app_settings', async () => {
  await ctx.database.pool.query(`UPDATE app_settings SET value = '0.65' WHERE key = 'reliability.prior'`);
  await signUp(ctx, 'zoe.nouvelle@etu.univ-smb.fr', { firstName: 'Zoé', lastName: 'Nouvelle' });
  const { rows } = await ctx.database.pool.query<{ s: string }>(
    `SELECT reliability_score AS s FROM users WHERE university_email = 'zoe.nouvelle@etu.univ-smb.fr'`,
  );
  expect(Number(rows[0]!.s)).toBe(0.65);
});
