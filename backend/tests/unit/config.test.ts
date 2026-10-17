import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../../src/config.js';

const base = {
  DATABASE_URL: 'postgres://u:secret@localhost:5432/db',
  JWT_SECRET: 'x'.repeat(32),
  CALENDAR_ENCRYPTION_KEY: Buffer.alloc(32, 1).toString('base64'),
};

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
    expect(() => loadConfig({ ...base, DATABASE_URL: 'mysql://localhost/db' })).toThrow(ConfigError);
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

describe('TRUST_PROXY', () => {
  it('vaut false par défaut et accepte "true"', () => {
    expect(loadConfig(base).TRUST_PROXY).toBe(false);
    expect(loadConfig({ ...base, TRUST_PROXY: 'true' }).TRUST_PROXY).toBe(true);
  });
});

describe('secrets et fournisseurs', () => {
  it('exige un JWT_SECRET de 32 caractères', () => {
    expect(() => loadConfig({ ...base, JWT_SECRET: 'court' })).toThrow(ConfigError);
  });

  it('refuse le mail console en production', () => {
    expect(() => loadConfig({ ...base, NODE_ENV: 'production' })).toThrow(/MAIL_PROVIDER/);
  });

  it('Brevo exige une clé', () => {
    expect(() => loadConfig({ ...base, MAIL_PROVIDER: 'brevo', BREVO_API_KEY: '' })).toThrow(/BREVO_API_KEY/);
    expect(loadConfig({ ...base, MAIL_PROVIDER: 'brevo', BREVO_API_KEY: 'k' }).MAIL_FROM).toBe('unimoov.support@gmail.com');
  });

  it('utilise la BAN par défaut', () => {
    expect(loadConfig(base).GEOCODING_PROVIDER).toBe('ban');
  });
});

describe('CALENDAR_ENCRYPTION_KEY', () => {
  it('exige 32 octets en base64', () => {
    expect(() => loadConfig({ ...base, CALENDAR_ENCRYPTION_KEY: Buffer.alloc(16).toString('base64') })).toThrow(
      ConfigError,
    );
  });
});

describe('ROUTING_PROVIDER', () => {
  it('estimation locale par défaut, sans clé ; une clé vide est tolérée', () => {
    expect(loadConfig(base).ROUTING_PROVIDER).toBe('estimate');
    expect(loadConfig({ ...base, ORS_API_KEY: '' }).ROUTING_DAILY_QUOTA).toBe(2000);
  });

  it('OpenRouteService exige une clé', () => {
    expect(() => loadConfig({ ...base, ROUTING_PROVIDER: 'ors', ORS_API_KEY: '' })).toThrow(/ORS_API_KEY/);
    expect(loadConfig({ ...base, ROUTING_PROVIDER: 'ors', ORS_API_KEY: 'k' }).ROUTING_PROVIDER).toBe('ors');
  });

  it('push FCM exige le fichier de la clé du compte de service ; journal par défaut', () => {
    expect(loadConfig(base).PUSH_PROVIDER).toBe('log');
    expect(() => loadConfig({ ...base, PUSH_PROVIDER: 'fcm' })).toThrow(/FCM_SERVICE_ACCOUNT_FILE/);
    expect(loadConfig({ ...base, PUSH_PROVIDER: 'fcm', FCM_SERVICE_ACCOUNT_FILE: '/secrets/fcm.json' }).PUSH_PROVIDER).toBe('fcm');
  });
});
