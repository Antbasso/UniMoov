import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { AUTH_POLICY } from './policy.js';

/** Fonctions pures de l'authentification, testées unitairement. */

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/** Domaine autorisé exact ou sous-domaine (`etu.univ-smb.fr` pour `univ-smb.fr`). */
export function isAllowedUniversityEmail(email: string, allowedDomains: readonly string[]): boolean {
  const at = email.lastIndexOf('@');
  if (at <= 0 || at === email.length - 1) return false;
  const domain = email.slice(at + 1).toLowerCase();
  return allowedDomains.some((allowed) => {
    const d = allowed.toLowerCase();
    return domain === d || domain.endsWith(`.${d}`);
  });
}

export function generateCode(random: (max: number) => number = randomInt): string {
  return String(random(10 ** AUTH_POLICY.codeLength)).padStart(AUTH_POLICY.codeLength, '0');
}

/** HMAC du code lié à l'adresse : un code volé en base ne sert pas pour une autre adresse. */
export function hashCode(secret: string, email: string, code: string): string {
  return createHmac('sha256', secret).update(`${email}:${code}`).digest('hex');
}

export function safeEqualHex(a: string, b: string): boolean {
  const left = Buffer.from(a, 'hex');
  const right = Buffer.from(b, 'hex');
  return left.length === right.length && timingSafeEqual(left, right);
}

export function generateRefreshToken(): string {
  return randomBytes(32).toString('base64url');
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export type CodeCheck = 'ok' | 'invalid' | 'expired' | 'locked';

export interface StoredCode {
  codeHash: string;
  attempts: number;
  expiresAt: Date;
  consumedAt: Date | null;
}

/** Décide du sort d'une tentative ; l'appelant incrémente `attempts` si ce n'est pas `ok`. */
export function checkCode(stored: StoredCode | undefined, providedHash: string, now: Date): CodeCheck {
  if (!stored || stored.consumedAt) return 'invalid';
  if (stored.expiresAt.getTime() <= now.getTime()) return 'expired';
  if (stored.attempts >= AUTH_POLICY.codeMaxAttempts) return 'locked';
  return safeEqualHex(stored.codeHash, providedHash) ? 'ok' : 'invalid';
}

export type RefreshCheck = 'ok' | 'unknown' | 'expired' | 'reused' | 'revoked';

export interface StoredRefreshToken {
  expiresAt: Date;
  usedAt: Date | null;
  revokedAt: Date | null;
}

export function checkRefreshToken(stored: StoredRefreshToken | undefined, now: Date): RefreshCheck {
  if (!stored) return 'unknown';
  // Un jeton déjà échangé qui revient : vol présumé, toute la famille est révoquée.
  if (stored.usedAt) return 'reused';
  if (stored.revokedAt) return 'revoked';
  if (stored.expiresAt.getTime() <= now.getTime()) return 'expired';
  return 'ok';
}

export function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60_000);
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}
