import { createSign } from 'node:crypto';

/** Notification push : titre, texte, données pour ouvrir le bon écran (identifiants seulement). */
export interface PushMessage {
  title: string;
  body: string;
  data: Record<string, string>;
}

/** Envoi push derrière une interface (architecture §8) ; renvoie les jetons à oublier. */
export interface PushProvider {
  send(tokens: readonly string[], message: PushMessage): Promise<{ invalidTokens: string[] }>;
}

/** Développement : journal du type d'envoi et du nombre d'appareils, sans contenu. */
export class LogPushProvider implements PushProvider {
  constructor(private readonly log: (data: object, message: string) => void) {}

  send(tokens: readonly string[], message: PushMessage): Promise<{ invalidTokens: string[] }> {
    this.log({ kind: message.data.type, devices: tokens.length }, 'push');
    return Promise.resolve({ invalidTokens: [] });
  }
}

/** Tests : garde les envois ; les jetons de `invalid` sont signalés comme périmés. */
export class MemoryPushProvider implements PushProvider {
  readonly sent: { tokens: string[]; message: PushMessage }[] = [];
  readonly invalid = new Set<string>();

  send(tokens: readonly string[], message: PushMessage): Promise<{ invalidTokens: string[] }> {
    this.sent.push({ tokens: [...tokens], message });
    return Promise.resolve({ invalidTokens: tokens.filter((t) => this.invalid.has(t)) });
  }
}

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

type Fetch = (
  url: string,
  init: { method: string; headers: Record<string, string>; body: string; signal?: AbortSignal },
) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}>;

const base64url = (input: string | Buffer) => Buffer.from(input).toString('base64url');

/**
 * Firebase Cloud Messaging, API HTTP v1 (palier gratuit, docs/couts.md). Jeton OAuth signé
 * avec la clé du compte de service (RS256, `node:crypto`), gardé jusqu'à 5 minutes avant son
 * expiration. Un appel par appareil ; un jeton inconnu de FCM est rendu pour être supprimé.
 */
export class FcmPushProvider implements PushProvider {
  private token: { value: string; expiresAt: number } | null = null;

  constructor(
    private readonly account: ServiceAccount,
    private readonly fetchFn: Fetch = (url, init) => fetch(url, init),
    private readonly now: () => number = Date.now,
  ) {}

  private async accessToken(): Promise<string> {
    if (this.token && this.token.expiresAt - 300_000 > this.now()) return this.token.value;
    const iat = Math.floor(this.now() / 1000);
    const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = base64url(
      JSON.stringify({
        iss: this.account.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat,
        exp: iat + 3600,
      }),
    );
    const signature = createSign('RSA-SHA256').update(`${header}.${claims}`).sign(this.account.private_key);
    const response = await this.fetchFn('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${header}.${claims}.${base64url(signature)}`,
      }).toString(),
    });
    if (!response.ok) throw new Error(`FCM : authentification refusée (HTTP ${response.status})`);
    const body = (await response.json()) as { access_token: string; expires_in: number };
    this.token = { value: body.access_token, expiresAt: this.now() + body.expires_in * 1000 };
    return body.access_token;
  }

  async send(tokens: readonly string[], message: PushMessage): Promise<{ invalidTokens: string[] }> {
    if (tokens.length === 0) return { invalidTokens: [] };
    const bearer = await this.accessToken();
    const invalidTokens: string[] = [];
    for (const token of tokens) {
      const response = await this.fetchFn(`https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
        // Un FCM lent n'immobilise ni la tâche ni la file.
        signal: AbortSignal.timeout(5000),
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: { priority: 'high' },
          },
        }),
      });
      // Jeton inconnu de FCM (application désinstallée) : 404, ou code UNREGISTERED. Un 400 dû à
      // la charge utile ne supprime aucun appareil.
      if (response.status === 404 || (!response.ok && (await errorCode(response)) === 'UNREGISTERED')) {
        invalidTokens.push(token);
      }
    }
    return { invalidTokens };
  }
}

async function errorCode(response: { json(): Promise<unknown> }): Promise<string | null> {
  try {
    const body = (await response.json()) as { error?: { details?: { errorCode?: string }[] } };
    return body.error?.details?.find((d) => d.errorCode)?.errorCode ?? null;
  } catch {
    return null;
  }
}
