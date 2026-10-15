import { describe, expect, it } from 'vitest';
import {
  checkCode,
  checkRefreshToken,
  generateCode,
  generateRefreshToken,
  hashCode,
  hashRefreshToken,
  isAllowedUniversityEmail,
  normalizeEmail,
} from '../../src/modules/auth/domain.js';
import { AUTH_POLICY } from '../../src/modules/auth/policy.js';

const domains = ['univ-smb.fr', 'etu.univ-smb.fr'];
const now = new Date('2026-10-15T10:00:00Z');
const later = (minutes: number) => new Date(now.getTime() + minutes * 60_000);

describe('isAllowedUniversityEmail', () => {
  it.each([
    ['lea.martin@etu.univ-smb.fr', true],
    ['prof@univ-smb.fr', true],
    ['x@sous.etu.univ-smb.fr', true],
    ['lea@gmail.com', false],
    ['lea@fakeuniv-smb.fr', false],
    ['lea@univ-smb.fr.evil.com', false],
    ['@univ-smb.fr', false],
    ['lea@', false],
    ['sans-arobase', false],
  ])('%s → %s', (email, expected) => {
    expect(isAllowedUniversityEmail(email, domains)).toBe(expected);
  });
});

describe('normalizeEmail', () => {
  it('met en minuscules et retire les espaces', () => {
    expect(normalizeEmail('  Lea.Martin@ETU.univ-smb.fr ')).toBe('lea.martin@etu.univ-smb.fr');
  });
});

describe('generateCode', () => {
  it('produit 6 chiffres, zéros de tête compris', () => {
    expect(generateCode(() => 42)).toBe('000042');
    expect(generateCode()).toMatch(/^\d{6}$/);
  });
});

describe('hashCode', () => {
  it('lie le code à l’adresse et au secret', () => {
    const a = hashCode('s', 'a@univ-smb.fr', '123456');
    expect(a).toBe(hashCode('s', 'a@univ-smb.fr', '123456'));
    expect(a).not.toBe(hashCode('s', 'b@univ-smb.fr', '123456'));
    expect(a).not.toBe(hashCode('autre', 'a@univ-smb.fr', '123456'));
  });
});

describe('checkCode', () => {
  const good = hashCode('s', 'a@univ-smb.fr', '123456');
  const stored = { codeHash: good, attempts: 0, expiresAt: later(10), consumedAt: null };

  it('accepte le bon code avant expiration', () => {
    expect(checkCode(stored, good, now)).toBe('ok');
  });

  it('refuse un mauvais code', () => {
    expect(checkCode(stored, hashCode('s', 'a@univ-smb.fr', '000000'), now)).toBe('invalid');
  });

  it('refuse un code expiré, même juste', () => {
    expect(checkCode(stored, good, later(10))).toBe('expired');
  });

  it('refuse un code déjà utilisé', () => {
    expect(checkCode({ ...stored, consumedAt: now }, good, now)).toBe('invalid');
  });

  it('bloque après le nombre maximal d’essais, même avec le bon code', () => {
    expect(checkCode({ ...stored, attempts: AUTH_POLICY.codeMaxAttempts }, good, now)).toBe('locked');
  });

  it('refuse en l’absence de code', () => {
    expect(checkCode(undefined, good, now)).toBe('invalid');
  });

  it('refuse un hash de longueur différente sans lever d’erreur', () => {
    expect(checkCode({ ...stored, codeHash: 'none' }, good, now)).toBe('invalid');
  });
});

describe('checkRefreshToken', () => {
  const token = { expiresAt: later(60), usedAt: null, revokedAt: null };
  it.each([
    ['valide', token, 'ok'],
    ['inconnu', undefined, 'unknown'],
    ['déjà utilisé (réutilisation)', { ...token, usedAt: now }, 'reused'],
    ['révoqué', { ...token, revokedAt: now }, 'revoked'],
    ['expiré', { ...token, expiresAt: now }, 'expired'],
  ] as const)('%s → %s', (_label, stored, expected) => {
    expect(checkRefreshToken(stored, now)).toBe(expected);
  });

  it('la réutilisation prime sur la révocation (détection du vol)', () => {
    expect(checkRefreshToken({ ...token, usedAt: now, revokedAt: now }, now)).toBe('reused');
  });
});

describe('jetons de rafraîchissement', () => {
  it('sont longs, uniques, et seul leur hash est stocké', () => {
    const a = generateRefreshToken();
    expect(a.length).toBeGreaterThanOrEqual(43);
    expect(a).not.toBe(generateRefreshToken());
    expect(hashRefreshToken(a)).toMatch(/^[0-9a-f]{64}$/);
  });
});
