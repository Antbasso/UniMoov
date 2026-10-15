import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../../src/config.js';

const base = { DATABASE_URL: 'postgres://u:secret@localhost:5432/db' };

describe('loadConfig', () => {
  it('applique les valeurs par défaut', () => {
    const config = loadConfig(base);
    expect(config).toMatchObject({ NODE_ENV: 'development', HOST: '0.0.0.0', PORT: 3000, LOG_LEVEL: 'info' });
  });

  it('convertit le port en nombre', () => {
    expect(loadConfig({ ...base, PORT: '8080' }).PORT).toBe(8080);
  });

  it('refuse une configuration sans base', () => {
    expect(() => loadConfig({})).toThrow(ConfigError);
  });

  it.each([['0'], ['70000'], ['abc']])('refuse le port %s', (port) => {
    expect(() => loadConfig({ ...base, PORT: port })).toThrow(ConfigError);
  });

  it('refuse une URL qui n’est pas PostgreSQL', () => {
    expect(() => loadConfig({ DATABASE_URL: 'mysql://localhost/db' })).toThrow(ConfigError);
  });

  it('ne divulgue pas les valeurs dans le message d’erreur', () => {
    try {
      loadConfig({ DATABASE_URL: 'mysql://u:secret@localhost/db' });
    } catch (error) {
      expect((error as Error).message).toContain('DATABASE_URL');
      expect((error as Error).message).not.toContain('secret');
    }
  });
});
