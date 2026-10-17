import { generateKeyPairSync, createVerify } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { UserHub } from '../../src/modules/chat/hub.js';
import { categoryOf, pushMessage } from '../../src/modules/notifications/service.js';
import type { NotificationEvent } from '../../src/shared/notifications/notifier.js';
import { FcmPushProvider } from '../../src/shared/push/push-provider.js';

const events: NotificationEvent[] = [
  { type: 'ride_cancelled', rideId: 'r1', by: 'driver' },
  { type: 'ride_cancelled', rideId: 'r1', by: 'passenger' },
  { type: 'replacement_proposed', rideId: 'r1' },
  { type: 'proposals_ready', week: '2026-W43' },
  { type: 'ride_reminder', rideId: 'r1', minutes: 58 },
  { type: 'chat_message', conversationId: 'c1', senderFirstName: 'Léa' },
];

describe('catégories de préférence (cahier §11)', () => {
  it('chaque événement a sa catégorie ; le chat se coupe sans toucher aux rappels', () => {
    expect(events.map(categoryOf)).toEqual(['ride_update', 'ride_update', 'match', 'match', 'ride_reminder', 'chat']);
  });
});

describe('texte des notifications', () => {
  it('jamais le contenu d’un message, au plus le prénom de son auteur', () => {
    const chat = pushMessage({ type: 'chat_message', conversationId: 'c1', senderFirstName: 'Léa' });
    expect(chat.title).toBe('Message de Léa');
    expect(chat.body).toBe('Ouvre Uni-Moov pour le lire.');
    expect(chat.data).toEqual({ type: 'chat_message', conversationId: 'c1' });
    expect(pushMessage({ type: 'chat_message', conversationId: 'c1', senderFirstName: '' }).title).toBe('Nouveau message');
  });

  it('rappel : minutes restantes ; données : identifiants pour ouvrir le bon écran', () => {
    expect(pushMessage({ type: 'ride_reminder', rideId: 'r1', minutes: 58 })).toEqual({
      title: 'Départ bientôt',
      body: 'Ton trajet part dans 58 min.',
      data: { type: 'ride_reminder', rideId: 'r1' },
    });
  });

  it('ton éditorial : phrases courtes, au plus une exclamation, pas d’emoji', () => {
    for (const e of events) {
      const { title, body } = pushMessage(e);
      expect(`${title} ${body}`.split('!').length).toBeLessThanOrEqual(2);
      expect(`${title}${body}`).not.toMatch(/\p{Extended_Pictographic}/u);
      expect(body.length).toBeLessThan(90);
    }
  });
});

describe('FcmPushProvider (API HTTP v1)', () => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' },
  });
  const account = { project_id: 'unimoov-383ff', client_email: 'push@unimoov-383ff.iam.gserviceaccount.com', private_key: privateKey };

  function fakeFetch(status: (token: string) => number) {
    const calls: { url: string; headers: Record<string, string>; body: string }[] = [];
    const fn = (url: string, init: { headers: Record<string, string>; body: string }) => {
      calls.push({ url, headers: init.headers, body: init.body });
      if (url.includes('oauth2')) {
        return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ access_token: 'acces-1', expires_in: 3600 }) });
      }
      const token = (JSON.parse(init.body) as { message: { token: string } }).message.token;
      return Promise.resolve({ ok: status(token) < 300, status: status(token), json: () => Promise.resolve({}) });
    };
    return { calls, fn };
  }

  it('jeton OAuth signé RS256 avec la clé du compte de service, puis un envoi par appareil', async () => {
    const { calls, fn } = fakeFetch(() => 200);
    const provider = new FcmPushProvider(account, fn, () => 1_800_000_000_000);
    const result = await provider.send(['jeton-a-123456', 'jeton-b-123456'], { title: 'T', body: 'B', data: { type: 'x' } });
    expect(result.invalidTokens).toEqual([]);
    expect(calls).toHaveLength(3);
    const assertion = new URLSearchParams(calls[0]!.body).get('assertion')!;
    const [header, claims, signature] = assertion.split('.');
    expect(createVerify('RSA-SHA256').update(`${header}.${claims}`).verify(publicKey, Buffer.from(signature!, 'base64url'))).toBe(true);
    expect(JSON.parse(Buffer.from(claims!, 'base64url').toString())).toMatchObject({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    });
    expect(calls[1]!.url).toBe('https://fcm.googleapis.com/v1/projects/unimoov-383ff/messages:send');
    expect(calls[1]!.headers.authorization).toBe('Bearer acces-1');
  });

  it('jeton OAuth réutilisé tant qu’il est valide ; jetons d’appareil inconnus signalés', async () => {
    const { calls, fn } = fakeFetch((token) => (token === 'perime-123456' ? 404 : 200));
    let now = 1_800_000_000_000;
    const provider = new FcmPushProvider(account, fn, () => now);
    expect((await provider.send(['perime-123456', 'valide-123456'], { title: 'T', body: 'B', data: {} })).invalidTokens).toEqual(['perime-123456']);
    now += 30 * 60_000;
    await provider.send(['valide-123456'], { title: 'T', body: 'B', data: {} });
    expect(calls.filter((c) => c.url.includes('oauth2'))).toHaveLength(1);
    // Moins de 5 minutes avant l'expiration : nouveau jeton.
    now += 27 * 60_000;
    await provider.send(['valide-123456'], { title: 'T', body: 'B', data: {} });
    expect(calls.filter((c) => c.url.includes('oauth2'))).toHaveLength(2);
  });

  it('aucun appareil : aucun appel réseau', async () => {
    const { calls, fn } = fakeFetch(() => 200);
    await new FcmPushProvider(account, fn).send([], { title: 'T', body: 'B', data: {} });
    expect(calls).toHaveLength(0);
  });
});

describe('UserHub', () => {
  it('plusieurs appareils par personne ; seuls les destinataires reçoivent', () => {
    const hub = new UserHub();
    const got: Record<string, string[]> = { a1: [], a2: [], b: [] };
    const socket = (name: string) => ({ send: (d: string) => got[name]!.push(d), close: () => undefined });
    const a1 = socket('a1');
    hub.add('a', a1);
    hub.add('a', socket('a2'));
    hub.add('b', socket('b'));
    hub.send(['a'], { type: 'message' });
    expect([got.a1!.length, got.a2!.length, got.b!.length]).toEqual([1, 1, 0]);
    hub.remove('a', a1);
    expect(hub.isOnline('a')).toBe(true);
    expect(hub.isOnline('c')).toBe(false);
  });
});
