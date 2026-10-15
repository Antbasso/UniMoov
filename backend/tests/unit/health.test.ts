import { describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';

const config = { LOG_LEVEL: 'silent' } as const;

describe('GET /health', () => {
  it('répond 200 quand la base répond', async () => {
    const app = await buildApp({ config, pingDb: () => Promise.resolve() });
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok', db: 'ok' });
    await app.close();
  });

  it('répond 503 quand la base est injoignable', async () => {
    const app = await buildApp({ config, pingDb: () => Promise.reject(new Error('down')) });
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(503);
    expect(response.json()).toEqual({ status: 'degraded', db: 'down' });
    await app.close();
  });
});

describe('format des erreurs', () => {
  it('renvoie { error: { code, message } } pour une route inconnue', async () => {
    const app = await buildApp({ config, pingDb: () => Promise.resolve() });
    const response = await app.inject({ method: 'GET', url: '/nope' });
    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual({ error: { code: 'not_found', message: 'Ressource introuvable' } });
    await app.close();
  });
});

describe('journaux', () => {
  it('ne contiennent ni IP, ni en-têtes, ni paramètres d’URL', async () => {
    const lines: string[] = [];
    const app = await buildApp({
      config: { LOG_LEVEL: 'info' },
      pingDb: () => Promise.resolve(),
      logStream: { write: (line) => lines.push(line) },
    });
    await app.inject({
      method: 'GET',
      url: '/health?token=secret-jwt&lat=45.9',
      headers: { authorization: 'Bearer secret-jwt' },
      remoteAddress: '203.0.113.7',
    });
    await app.close();
    const output = lines.join('');
    expect(output).toContain('"route":"/health"');
    expect(output).not.toMatch(/secret-jwt|203\.0\.113\.7|45\.9/);
  });
});

describe('erreurs client de Fastify', () => {
  it.each([
    ['application/json', '{bad', 400, 'bad_request'],
    ['text/xml', '<a/>', 415, 'unsupported_media_type'],
  ])('%s mal formé → %i %s (pas 500)', async (contentType, payload, status, code) => {
    const app = await buildApp({ config, pingDb: () => Promise.resolve() });
    app.post('/probe', () => ({ ok: true }));
    const response = await app.inject({
      method: 'POST',
      url: '/probe',
      headers: { 'content-type': contentType },
      payload,
    });
    expect(response.statusCode).toBe(status);
    expect(response.json()).toEqual({ error: { code, message: 'Requête invalide' } });
    await app.close();
  });
});
