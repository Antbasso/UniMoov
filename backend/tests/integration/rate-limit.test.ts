import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { setupTestContext, type TestContext } from './helpers.js';

let ctx: TestContext;
beforeAll(async () => {
  ctx = await setupTestContext(undefined, { rateLimit: true });
});
afterAll(async () => {
  await ctx.close();
});

describe('limite de débit', () => {
  it('bloque la connexion après 10 essais en 15 minutes', async () => {
    const attempt = () =>
      ctx.app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: { universityEmail: 'x@etu.univ-smb.fr', password: 'faux' },
      });
    for (let i = 0; i < 10; i++) expect((await attempt()).statusCode).toBe(401);
    const blocked = await attempt();
    expect(blocked.statusCode).toBe(429);
    expect(blocked.json()).toMatchObject({ error: { code: 'rate_limited' } });
  });

  it('bloque l’envoi de code après 5 demandes', async () => {
    const ask = (i: number) =>
      ctx.app.inject({
        method: 'POST',
        url: '/api/v1/auth/signup/request-code',
        payload: { universityEmail: `spam${i}@etu.univ-smb.fr` },
      });
    for (let i = 0; i < 5; i++) expect((await ask(i)).statusCode).toBe(202);
    expect((await ask(99)).statusCode).toBe(429);
  });
});
