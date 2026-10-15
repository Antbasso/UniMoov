import { lookup as dnsLookup, type LookupAddress } from 'node:dns';
import https from 'node:https';
import net from 'node:net';

/**
 * Téléchargement d'une URL fournie par un utilisateur (lien ICS) sans exposer le réseau
 * interne (SSRF) : HTTPS sur le port 443 uniquement, adresses privées refusées à la
 * résolution DNS (au moment même de la connexion), taille, durée et redirections bornées.
 */
export class UnsafeUrlError extends Error {
  override readonly name = 'UnsafeUrlError';
}

export class FetchFailedError extends Error {
  override readonly name = 'FetchFailedError';
}

const V4_BLOCKED: [string, number][] = [
  ['0.0.0.0', 8],
  ['10.0.0.0', 8],
  ['100.64.0.0', 10],
  ['127.0.0.0', 8],
  ['169.254.0.0', 16],
  ['172.16.0.0', 12],
  ['192.0.0.0', 24],
  ['192.168.0.0', 16],
  ['198.18.0.0', 15],
  ['224.0.0.0', 4],
  ['240.0.0.0', 4],
];

function v4ToInt(ip: string): number {
  return ip.split('.').reduce((acc, part) => (acc << 8) + Number(part), 0) >>> 0;
}

/** Adresse joignable sur Internet public (ni locale, ni privée, ni réservée). */
export function isPublicAddress(ip: string): boolean {
  const version = net.isIP(ip);
  if (version === 4) {
    const value = v4ToInt(ip);
    return !V4_BLOCKED.some(([base, bits]) => {
      const mask = bits === 0 ? 0 : (~0 << (32 - bits)) >>> 0;
      return (value & mask) === (v4ToInt(base) & mask);
    });
  }
  if (version === 6) {
    const lower = ip.toLowerCase();
    const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/.exec(lower);
    if (mapped) return isPublicAddress(mapped[1]!);
    if (lower === '::' || lower === '::1') return false;
    const first = parseInt(lower.split(':')[0] || '0', 16);
    if ((first & 0xfe00) === 0xfc00) return false; // fc00::/7 local unique
    if ((first & 0xffc0) === 0xfe80) return false; // fe80::/10 lien local
    if ((first & 0xff00) === 0xff00) return false; // multidiffusion
    return true;
  }
  return false;
}

/** Valide et normalise un lien ICS (`webcal://` → `https://`). */
export function normalizeCalendarUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw.trim().replace(/^webcals?:\/\//i, 'https://'));
  } catch {
    throw new UnsafeUrlError('Lien invalide');
  }
  if (url.protocol !== 'https:') throw new UnsafeUrlError('Lien HTTPS requis');
  if (url.port && url.port !== '443') throw new UnsafeUrlError('Port non autorisé');
  if (url.username || url.password) throw new UnsafeUrlError('Identifiants interdits dans le lien');
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (net.isIP(host) && !isPublicAddress(host)) throw new UnsafeUrlError('Adresse non autorisée');
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.internal')) {
    throw new UnsafeUrlError('Adresse non autorisée');
  }
  return url;
}

type LookupCallback = (err: NodeJS.ErrnoException | null, address: string | LookupAddress[], family?: number) => void;

function guardedLookup(hostname: string, options: object, callback: LookupCallback): void {
  dnsLookup(hostname, { ...options, all: true }, (err, addresses) => {
    if (err) return callback(err, '');
    const list = addresses;
    if (list.length === 0 || list.some((a) => !isPublicAddress(a.address))) {
      return callback(Object.assign(new Error('Adresse non autorisée'), { code: 'EBLOCKED' }), '');
    }
    if ((options as { all?: boolean }).all) return callback(null, list);
    return callback(null, list[0]!.address, list[0]!.family);
  });
}

export interface SafeFetchOptions {
  maxBytes?: number;
  timeoutMs?: number;
  maxRedirects?: number;
}

export async function fetchPublicText(raw: string, options: SafeFetchOptions = {}): Promise<string> {
  const { maxBytes = 2_000_000, timeoutMs = 10_000, maxRedirects = 3 } = options;
  const url = normalizeCalendarUrl(raw);

  return new Promise((resolve, reject) => {
    // `timeout` ci-dessous ne mesure que l'inactivité ; ce délai borne la durée totale
    // (serveur qui envoie au compte-gouttes).
    const deadline = setTimeout(() => request.destroy(new FetchFailedError('Délai dépassé')), timeoutMs);
    const settle = <T>(fn: (value: T) => void) => (value: T) => {
      clearTimeout(deadline);
      fn(value);
    };
    resolve = settle(resolve);
    reject = settle(reject);
    const request = https.get(
      url,
      { lookup: guardedLookup, timeout: timeoutMs, headers: { accept: 'text/calendar, */*' } },
      (response) => {
        const status = response.statusCode ?? 0;
        if (status >= 300 && status < 400 && response.headers.location) {
          response.resume();
          if (maxRedirects <= 0) return reject(new FetchFailedError('Trop de redirections'));
          const next = new URL(response.headers.location, url).toString();
          fetchPublicText(next, { maxBytes, timeoutMs, maxRedirects: maxRedirects - 1 }).then(resolve, reject);
          return;
        }
        if (status !== 200) {
          response.resume();
          return reject(new FetchFailedError(`HTTP ${status}`));
        }
        const chunks: Buffer[] = [];
        let size = 0;
        response.on('data', (chunk: Buffer) => {
          size += chunk.length;
          if (size > maxBytes) {
            request.destroy();
            reject(new FetchFailedError('Fichier trop volumineux'));
            return;
          }
          chunks.push(chunk);
        });
        response.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
        response.on('error', () => reject(new FetchFailedError('Lecture interrompue')));
      },
    );
    request.on('timeout', () => request.destroy(new FetchFailedError('Délai dépassé')));
    request.on('error', (error) =>
      reject(error instanceof FetchFailedError || error instanceof UnsafeUrlError ? error : new FetchFailedError(error.message)),
    );
  });
}
