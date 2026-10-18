import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type WebSocket from 'ws';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/**
 * Critères de M6 : un chat est créé à la confirmation et archivé après la durée configurée ;
 * un utilisateur n'accède qu'à ses conversations. Plus les notifications push.
 */
let ctx: TestContext;
const tokens = new Map<string, Tokens>();
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;

async function login(firstName: string): Promise<Tokens> {
  const cached = tokens.get(firstName);
  if (cached) return cached;
  const response = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: { universityEmail: user(firstName).email, password: DEMO_PASSWORD },
  });
  const t = response.json<Tokens>();
  tokens.set(firstName, t);
  return t;
}

async function call(firstName: string, method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE', url: string, payload?: object) {
  return ctx.app.inject({
    method,
    url: `/api/v1${url}`,
    headers: bearer(await login(firstName)),
    ...(payload ? { payload } : {}),
  });
}
const code = (response: { json: <T>() => T }) => response.json<{ error: { code: string } }>().error.code;

interface Conversation {
  id: string;
  kind: string;
  title?: string | null;
  ride: { day: string; direction: string } | null;
  archived: boolean;
  members: Record<string, unknown>[];
  unread: number;
  lastMessage: { body: string } | null;
}

async function waitFor<T>(fn: () => T | undefined, timeoutMs = 3000): Promise<T> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const value = fn();
    if (value !== undefined) return value;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error('délai dépassé');
}

let rideId: string;
let chatId: string;
let tuesdayId: string;

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
  await runSeed(ctx.database.db, { today: '2026-10-19' });
  const list = await call('Léa', 'GET', '/proposals?week=2026-W43');
  rideId = list.json<{ proposals: { id: string; day: string; direction: string }[] }>().proposals.find(
    (p) => p.day === '2026-10-19' && p.direction === 'to_campus',
  )!.id;
  for (const name of ['Léa', 'Hugo']) expect((await call(name, 'POST', `/proposals/${rideId}/accept`)).statusCode).toBe(200);
  // Trajet du mardi confirmé, qui ne partira jamais (rétention des trajets abandonnés).
  tuesdayId = list.json<{ proposals: { id: string; day: string; direction: string }[] }>().proposals.find(
    (p) => p.day === '2026-10-20' && p.direction === 'to_campus',
  )!.id;
  for (const name of ['Léa', 'Inès']) expect((await call(name, 'POST', `/proposals/${tuesdayId}/accept`)).statusCode).toBe(200);
  // Appareils enregistrés pour les push.
  for (const [name, token] of [['Inès', 'jeton-ines-0001'], ['Hugo', 'jeton-hugo-0001'], ['Léa', 'jeton-lea-00001']] as const) {
    expect((await call(name, 'POST', '/devices', { platform: 'android', pushToken: token })).statusCode).toBe(204);
  }
});
afterAll(async () => {
  await ctx.close();
});

describe('chat de trajet (cahier §6)', () => {
  it('créé à la confirmation avec les personnes acceptées, prénoms seulement', async () => {
    const response = await call('Hugo', 'GET', `/rides/${rideId}/conversation`);
    expect(response.statusCode).toBe(200);
    const chat = response.json<Conversation>();
    chatId = chat.id;
    expect(chat.kind).toBe('ride');
    expect(chat.ride).toEqual({ day: '2026-10-19', direction: 'to_campus' });
    expect(chat.members.map((m) => m.firstName).sort()).toEqual(['Hugo', 'Léa']);
    // Nom de famille et adresse ne sortent jamais par la messagerie.
    expect(Object.keys(chat.members[0]!).sort()).toEqual(['firstName', 'photoUrl', 'userId']);
  });

  it('suit les acceptations et les annulations', async () => {
    expect((await call('Inès', 'GET', `/rides/${rideId}/conversation`)).statusCode).toBe(404);
    expect((await call('Inès', 'POST', `/proposals/${rideId}/accept`)).statusCode).toBe(200);
    expect((await call('Inès', 'GET', `/conversations/${chatId}`)).statusCode).toBe(200);
    expect((await call('Chloé', 'POST', `/proposals/${rideId}/accept`)).statusCode).toBe(200);
    expect((await call('Chloé', 'POST', `/rides/${rideId}/cancel`)).statusCode).toBe(200);
    expect((await call('Chloé', 'GET', `/conversations/${chatId}`)).statusCode).toBe(404);
    const members = (await call('Léa', 'GET', `/conversations/${chatId}`)).json<Conversation>().members;
    expect(members.map((m) => m.firstName).sort()).toEqual(['Hugo', 'Inès', 'Léa']);
  });

  it('un utilisateur n’accède qu’à ses conversations (404, sans révéler leur existence)', async () => {
    expect((await call('Nathan', 'GET', `/conversations/${chatId}`)).statusCode).toBe(404);
    expect((await call('Nathan', 'GET', `/conversations/${chatId}/messages`)).statusCode).toBe(404);
    expect((await call('Nathan', 'POST', `/conversations/${chatId}/messages`, { body: 'intrus' })).statusCode).toBe(404);
    expect((await call('Nathan', 'GET', `/rides/${rideId}/conversation`)).statusCode).toBe(404);
    expect((await call('Nathan', 'GET', '/conversations')).json<{ conversations: Conversation[] }>().conversations).toEqual([]);
  });
});

describe('messages en direct et push', () => {
  it('message reçu en direct par les membres connectés, push aux autres, sans le texte', async () => {
    const ws: WebSocket = await ctx.app.injectWS(`/api/v1/ws/me?token=${encodeURIComponent((await login('Inès')).accessToken)}`);
    const received: Record<string, unknown>[] = [];
    ws.on('message', (data: Buffer) => received.push(JSON.parse(data.toString()) as Record<string, unknown>));
    await waitFor(() => received.find((m) => m.type === 'ready'));
    ctx.push.sent.length = 0;

    const sent = await call('Léa', 'POST', `/conversations/${chatId}/messages`, { body: 'Je pars à 7 h 40, à tout de suite.' });
    expect(sent.statusCode).toBe(201);
    const live = await waitFor(() => received.find((m) => m.type === 'message'));
    expect((live.message as { body: string }).body).toBe('Je pars à 7 h 40, à tout de suite.');

    // Inès est connectée : pas de push. Hugo ne l'est pas : push sans le contenu du message
    // (envoyé en tâche de fond, après la réponse).
    await waitFor(() => (ctx.push.sent.length > 0 ? true : undefined));
    expect(ctx.push.sent).toHaveLength(1);
    expect(ctx.push.sent[0]!.tokens).toEqual(['jeton-hugo-0001']);
    expect(ctx.push.sent[0]!.message.title).toBe('Message de Léa');
    expect(JSON.stringify(ctx.push.sent[0]!.message)).not.toContain('7 h 40');
    ws.close();
  });

  it('non lus, lecture, pagination, validation', async () => {
    const hugo = (await call('Hugo', 'GET', '/conversations')).json<{ conversations: Conversation[] }>().conversations;
    expect(hugo.find((c) => c.id === chatId)).toMatchObject({ unread: 1, lastMessage: { body: 'Je pars à 7 h 40, à tout de suite.' } });
    expect((await call('Hugo', 'POST', `/conversations/${chatId}/read`)).statusCode).toBe(204);
    const after = (await call('Hugo', 'GET', '/conversations')).json<{ conversations: Conversation[] }>().conversations;
    expect(after.find((c) => c.id === chatId)!.unread).toBe(0);

    ctx.clock.advance(1000);
    await call('Hugo', 'POST', `/conversations/${chatId}/messages`, { body: 'Ok, merci.' });
    const page = await call('Inès', 'GET', `/conversations/${chatId}/messages?limit=1`);
    const [latest] = page.json<{ messages: { id: string; body: string; createdAt: string }[] }>().messages;
    expect(latest!.body).toBe('Ok, merci.');
    const older = await call(
      'Inès',
      'GET',
      `/conversations/${chatId}/messages?before=${encodeURIComponent(latest!.createdAt)}&beforeId=${latest!.id}`,
    );
    expect(older.json<{ messages: { body: string }[] }>().messages.map((m) => m.body)).toEqual(['Je pars à 7 h 40, à tout de suite.']);

    expect((await call('Hugo', 'POST', `/conversations/${chatId}/messages`, { body: '   ' })).statusCode).toBe(400);
    expect((await call('Hugo', 'POST', `/conversations/${chatId}/messages`, { body: 'x'.repeat(2001) })).statusCode).toBe(400);
  });

  it('préférences : couper le chat garde les rappels de trajet', async () => {
    const prefs = await call('Hugo', 'PUT', '/me/notification-preferences', { chat: false });
    expect(prefs.json()).toEqual({ match: true, rideUpdate: true, rideReminder: true, chat: false });
    ctx.push.sent.length = 0;
    await call('Léa', 'POST', `/conversations/${chatId}/messages`, { body: 'Petit retard.' });
    await new Promise((r) => setTimeout(r, 50));
    expect(ctx.push.sent.flatMap((p) => p.tokens)).not.toContain('jeton-hugo-0001');

    // Rappel une heure avant le départ (trajet à 8 h, départ de Léa vers 7 h 40 à Paris).
    ctx.clock.now = new Date('2026-10-19T04:30:00Z');
    expect(await ctx.app.services!.notifications.sendReminders()).toBe(0);
    ctx.clock.now = new Date('2026-10-19T05:00:00Z');
    ctx.push.sent.length = 0;
    expect(await ctx.app.services!.notifications.sendReminders()).toBe(3);
    const tokensReminded = ctx.push.sent.filter((p) => p.message.data.type === 'ride_reminder').flatMap((p) => p.tokens);
    expect(tokensReminded.sort()).toEqual(['jeton-hugo-0001', 'jeton-ines-0001', 'jeton-lea-00001']);
    // Un seul rappel par personne et par trajet.
    expect(await ctx.app.services!.notifications.sendReminders()).toBe(0);
  });

  it('jeton refusé par FCM : appareil oublié ; déconnexion : appareil retiré', async () => {
    ctx.push.invalid.add('jeton-ines-0001');
    await ctx.app.services!.notifications.notify([user('Inès').id], { type: 'proposals_ready', week: '2026-W43' });
    ctx.push.sent.length = 0;
    await ctx.app.services!.notifications.notify([user('Inès').id], { type: 'proposals_ready', week: '2026-W43' });
    expect(ctx.push.sent).toHaveLength(0);

    expect((await call('Léa', 'DELETE', '/devices', { pushToken: 'jeton-lea-00001' })).statusCode).toBe(204);
    await ctx.app.services!.notifications.notify([user('Léa').id], { type: 'proposals_ready', week: '2026-W43' });
    expect(ctx.push.sent).toHaveLength(0);
  });
});

describe('réactions et photos', () => {
  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 1)]);

  it('une réaction par personne, remplacée ou retirée, vue par tous ; jeu fermé', async () => {
    const [latest] = (await call('Inès', 'GET', `/conversations/${chatId}/messages?limit=1`)).json<{ messages: { id: string }[] }>().messages;
    const url = `/conversations/${chatId}/messages/${latest!.id}/reaction`;
    expect((await call('Inès', 'PUT', url, { emoji: '👍' })).statusCode).toBe(200);
    expect((await call('Hugo', 'PUT', url, { emoji: '😂' })).statusCode).toBe(200);
    const replaced = await call('Inès', 'PUT', url, { emoji: '❤️' });
    expect(replaced.json<{ reactions: unknown[] }>().reactions).toEqual([
      { userId: user('Hugo').id, emoji: '😂' },
      { userId: user('Inès').id, emoji: '❤️' },
    ]);
    // Tous les emojis du clavier (teintes, drapeaux, familles), mais rien d'autre.
    for (const emoji of ['🤡', '👍🏽', '🇫🇷', '👨‍👩‍👧']) expect((await call('Hugo', 'PUT', url, { emoji })).statusCode).toBe(200);
    expect((await call('Hugo', 'DELETE', url)).statusCode).toBe(200);
    for (const emoji of ['ok', '<b>', '👍 ok']) expect((await call('Inès', 'PUT', url, { emoji })).statusCode).toBe(400);
    expect((await call('Hugo', 'PUT', url, { emoji: '😂' })).statusCode).toBe(200);
    expect((await call('Nathan', 'PUT', url, { emoji: '👍' })).statusCode).toBe(404);
    const removed = await call('Hugo', 'DELETE', url);
    expect(removed.json<{ reactions: unknown[] }>().reactions).toEqual([{ userId: user('Inès').id, emoji: '❤️' }]);
  });

  it('photo avec légende facultative, servie aux seuls membres ; contrôlée sur ses octets', async () => {
    const send = (body: Buffer, type: string, query = '') =>
      login('Léa').then((t) =>
        ctx.app.inject({
          method: 'POST',
          url: `/api/v1/conversations/${chatId}/photos${query}`,
          headers: { ...bearer(t), 'content-type': type },
          payload: body,
        }),
      );
    const sent = await send(jpeg, 'image/jpeg', `?caption=${encodeURIComponent('Je suis là')}`);
    expect(sent.statusCode).toBe(201);
    const message = sent.json<{ id: string; body: string; photoUrl: string }>();
    expect(message.body).toBe('Je suis là');
    expect(message.photoUrl).toBe(`/api/v1/conversations/${chatId}/messages/${message.id}/photo`);
    const photo = await ctx.app.inject({ method: 'GET', url: message.photoUrl, headers: bearer(await login('Hugo')) });
    expect(photo.statusCode).toBe(200);
    expect(photo.headers['content-type']).toBe('image/jpeg');
    expect(photo.rawPayload.equals(jpeg)).toBe(true);
    expect((await ctx.app.inject({ method: 'GET', url: message.photoUrl, headers: bearer(await login('Nathan')) })).statusCode).toBe(404);
    // Sans légende : permis pour une photo ; un faux JPEG est refusé.
    expect((await send(jpeg, 'image/jpeg')).json<{ body: string }>().body).toBe('');
    expect((await send(Buffer.from('pas une image'), 'image/jpeg')).statusCode).toBe(400);
    expect((await send(Buffer.alloc(700 * 1024, 0xff), 'image/jpeg')).statusCode).toBe(413);
    // Aperçu de la liste : le dernier message est une photo.
    const list = (await call('Hugo', 'GET', '/conversations')).json<{ conversations: (Conversation & { lastMessage: { photoUrl: string | null } })[] }>();
    expect(list.conversations.find((c) => c.id === chatId)!.lastMessage.photoUrl).not.toBeNull();
  });
});

describe('messages privés et groupes', () => {
  it('seulement avec des personnes croisées sur un trajet ; une conversation privée par paire', async () => {
    const contacts = (await call('Hugo', 'GET', '/contacts')).json<{ contacts: { firstName: string }[] }>().contacts;
    expect(contacts.map((c) => c.firstName)).toEqual(expect.arrayContaining(['Léa', 'Inès']));
    expect(contacts.map((c) => c.firstName)).not.toContain('Théo');

    const first = await call('Hugo', 'POST', '/conversations', { kind: 'direct', memberIds: [user('Inès').id] });
    expect(first.statusCode).toBe(201);
    const again = await call('Inès', 'POST', '/conversations', { kind: 'direct', memberIds: [user('Hugo').id] });
    expect(again.json<Conversation>().id).toBe(first.json<Conversation>().id);
    expect(code(await call('Hugo', 'POST', '/conversations', { kind: 'direct', memberIds: [user('Théo').id] }))).toBe('not_a_contact');
  });

  it('création simultanée d’une conversation privée : une seule, sans erreur', async () => {
    const [a, b] = await Promise.all([
      call('Léa', 'POST', '/conversations', { kind: 'direct', memberIds: [user('Inès').id] }),
      call('Inès', 'POST', '/conversations', { kind: 'direct', memberIds: [user('Léa').id] }),
    ]);
    expect([a.statusCode, b.statusCode]).toEqual([201, 201]);
    expect(a.json<Conversation>().id).toBe(b.json<Conversation>().id);
  });

  it('groupe nommé ; le quitter ; un privé ne se quitte pas', async () => {
    expect((await call('Hugo', 'POST', '/conversations', { kind: 'group', memberIds: [user('Inès').id] })).statusCode).toBe(400);
    const group = await call('Hugo', 'POST', '/conversations', {
      kind: 'group',
      title: 'Seynod le lundi',
      memberIds: [user('Inès').id, user('Léa').id],
    });
    expect(group.statusCode).toBe(201);
    const id = group.json<Conversation>().id;
    expect((await call('Inès', 'DELETE', `/conversations/${id}/members/me`)).statusCode).toBe(204);
    expect((await call('Inès', 'GET', `/conversations/${id}`)).statusCode).toBe(404);
    expect(code(await call('Hugo', 'DELETE', `/conversations/${chatId}/members/me`))).toBe('cannot_leave');
  });

  it('gérer un groupe : renommer, ajouter une personne croisée, retirer (créateur seulement)', async () => {
    const group = await call('Hugo', 'POST', '/conversations', { kind: 'group', title: 'Aller du lundi', memberIds: [user('Léa').id] });
    const id = group.json<Conversation & { createdBy: string }>().id;
    expect(group.json<{ createdBy: string }>().createdBy).toBe(user('Hugo').id);
    const renamed = await call('Léa', 'PATCH', `/conversations/${id}`, { title: 'Covoit du lundi' });
    expect(renamed.json<Conversation>().title).toBe('Covoit du lundi');
    // Nathan n'a jamais croisé Hugo : refusé ; Inès oui.
    expect(code(await call('Hugo', 'POST', `/conversations/${id}/members`, { memberIds: [user('Nathan').id] }))).toBe('not_a_contact');
    const added = await call('Hugo', 'POST', `/conversations/${id}/members`, { memberIds: [user('Inès').id] });
    expect(added.json<Conversation>().members.map((m) => m.firstName).sort()).toEqual(['Hugo', 'Inès', 'Léa']);
    // Seul le créateur retire quelqu'un ; un intrus ne voit rien ; un privé ne se gère pas.
    expect((await call('Léa', 'DELETE', `/conversations/${id}/members/${user('Inès').id}`)).statusCode).toBe(403);
    const removed = await call('Hugo', 'DELETE', `/conversations/${id}/members/${user('Inès').id}`);
    expect(removed.json<Conversation>().members.map((m) => m.firstName).sort()).toEqual(['Hugo', 'Léa']);
    expect((await call('Nathan', 'PATCH', `/conversations/${id}`, { title: 'x' })).statusCode).toBe(404);
    expect(code(await call('Hugo', 'PATCH', `/conversations/${chatId}`, { title: 'x' }))).toBe('not_a_group');
  });

  it('covoiturage de groupe : offre du conducteur, demande d’un passager, acceptées d’un toucher', async () => {
    const group = await call('Léa', 'POST', '/conversations', {
      kind: 'group',
      title: 'Covoit Seynod',
      memberIds: [user('Chloé').id, user('Hugo').id],
    });
    const id = group.json<Conversation>().id;
    interface Carpool { id: string; body: string; carpool: { kind: string; rideId: string | null; day: string; time: string | null; joined: { firstName: string }[] } }
    const seat = async (name: string, ride: string) =>
      (await ctx.database.pool.query<{ status: string }>(`SELECT status FROM ride_participants WHERE ride_id = $1 AND user_id = $2`, [ride, user(name).id])).rows[0]?.status;

    // Offre : Léa partage son trajet du lundi (elle le conduit) ; Chloé monte d'un toucher.
    expect(code(await call('Hugo', 'POST', `/conversations/${id}/carpool`, { kind: 'offer', rideId }))).toBe('ride_unavailable');
    const offer = await call('Léa', 'POST', `/conversations/${id}/carpool`, { kind: 'offer', rideId });
    expect(offer.statusCode).toBe(201);
    const posted = offer.json<Carpool>();
    expect(posted.carpool).toMatchObject({ kind: 'offer', rideId, day: '2026-10-19', joined: [] });
    expect(posted.carpool.time).not.toBeNull();
    expect(code(await call('Léa', 'POST', `/conversations/${id}/messages/${posted.id}/carpool/accept`))).toBe('own_carpool');
    const accepted = await call('Chloé', 'POST', `/conversations/${id}/messages/${posted.id}/carpool/accept`);
    expect(accepted.statusCode).toBe(200);
    expect(accepted.json<Carpool>().carpool.joined.map((j) => j.firstName)).toEqual(['Chloé']);
    expect(await seat('Chloé', rideId)).toBe('accepted');
    expect(ctx.notifier.sent).toContainEqual({ userIds: [user('Léa').id, user('Chloé').id], event: { type: 'carpool_joined', rideId } });
    // Rejoué : sans effet.
    expect((await call('Chloé', 'POST', `/conversations/${id}/messages/${posted.id}/carpool/accept`)).statusCode).toBe(200);

    // Demande : Chloé cherche une voiture mardi ; Hugo ne conduit pas, Léa (qui conduit) la prend.
    const request = await call('Chloé', 'POST', `/conversations/${id}/carpool`, { kind: 'request', day: '2026-10-20', direction: 'to_campus' });
    expect(request.statusCode).toBe(201);
    const asked = request.json<Carpool>();
    expect(asked.carpool).toMatchObject({ kind: 'request', rideId: null, day: '2026-10-20' });
    expect(code(await call('Hugo', 'POST', `/conversations/${id}/messages/${asked.id}/carpool/accept`))).toBe('no_ride_that_day');
    expect((await call('Léa', 'POST', `/conversations/${id}/messages/${asked.id}/carpool/accept`)).statusCode).toBe(200);
    expect(await seat('Chloé', tuesdayId)).toBe('accepted');
    // Les messages relus portent la proposition et qui est monté.
    const messages = (await call('Hugo', 'GET', `/conversations/${id}/messages`)).json<{ messages: Carpool[] }>().messages;
    expect(messages.find((m) => m.id === asked.id)!.carpool.joined.map((j) => j.firstName)).toEqual(['Chloé']);
    // Créer son propre trajet depuis la conversation : Léa conduit jeudi à 8 h 15 ; Hugo monte.
    const created = await call('Léa', 'POST', `/conversations/${id}/carpool`, {
      kind: 'offer',
      create: { day: '2026-10-22', direction: 'to_campus', time: '08:15' },
    });
    expect(created.statusCode).toBe(201);
    const fresh = created.json<Carpool>();
    expect(fresh.carpool).toMatchObject({ kind: 'offer', day: '2026-10-22' });
    expect(fresh.carpool.time).toBe('2026-10-22T06:15:00.000Z');
    const newRide = fresh.carpool.rideId!;
    expect(await seat('Léa', newRide)).toBe('accepted');
    const joined = await call('Hugo', 'POST', `/conversations/${id}/messages/${fresh.id}/carpool/accept`);
    expect(joined.json<{ carpool: { joined: { rideId: string }[] } }>().carpool.joined[0]!.rideId).toBe(newRide);
    expect(await seat('Hugo', newRide)).toBe('accepted');
    // Déjà engagée sur ce créneau : pas un second trajet.
    expect(code(await call('Léa', 'POST', '/rides', { day: '2026-10-22', direction: 'to_campus', time: '09:00' }))).toBe('already_committed');
    // Une demande peut porter une heure.
    const timed = await call('Chloé', 'POST', `/conversations/${id}/carpool`, { kind: 'request', day: '2026-10-23', direction: 'from_campus', time: '17:30' });
    expect(timed.json<Carpool>().carpool.time).toBe('2026-10-23T15:30:00.000Z');

    // Pas dans un chat de trajet ; jamais pour un jour passé.
    expect(code(await call('Léa', 'POST', `/conversations/${chatId}/carpool`, { kind: 'offer', rideId }))).toBe('carpool_not_here');
    expect((await call('Chloé', 'POST', `/conversations/${id}/carpool`, { kind: 'request', day: '2026-10-01', direction: 'to_campus' })).statusCode).toBe(400);
  });
});

describe('rétention du chat de trajet (cahier §6)', () => {
  it('trajet fini : lisible, puis archivé (lecture seule) après la durée configurée, puis supprimé', async () => {
    ctx.clock.now = new Date('2026-10-19T05:30:00Z');
    expect((await call('Léa', 'POST', `/rides/${rideId}/start`)).statusCode).toBe(204);
    ctx.clock.now = new Date('2026-10-19T06:05:00Z');
    expect((await call('Léa', 'POST', `/rides/${rideId}/finish`)).statusCode).toBe(204);
    expect(await ctx.app.services!.chat.applyRetention()).toEqual({ scheduled: 1, deleted: 0 });
    expect((await call('Hugo', 'POST', `/conversations/${chatId}/messages`, { body: 'Merci pour le trajet.' })).statusCode).toBe(201);

    // 7 jours après la fin (chat.rideArchiveDays) : archivé, lecture seule.
    ctx.clock.now = new Date('2026-10-26T06:06:00Z');
    expect(code(await call('Hugo', 'POST', `/conversations/${chatId}/messages`, { body: 'Encore là ?' }))).toBe('conversation_archived');
    const archived = (await call('Hugo', 'GET', `/conversations/${chatId}`)).json<Conversation>();
    expect(archived.archived).toBe(true);
    expect((await call('Hugo', 'GET', `/conversations/${chatId}/messages`)).statusCode).toBe(200);

    // 30 jours plus tard (chat.rideDeleteDays) : supprimé avec ses messages.
    ctx.clock.now = new Date('2026-11-25T06:07:00Z');
    expect((await ctx.app.services!.chat.applyRetention()).deleted).toBeGreaterThanOrEqual(1);
    expect((await call('Hugo', 'GET', `/conversations/${chatId}`)).statusCode).toBe(404);
    const { rows } = await ctx.database.pool.query<{ n: number }>('SELECT count(*)::int AS n FROM messages WHERE conversation_id = $1', [chatId]);
    expect(rows[0]!.n).toBe(0);
  });
  it('trajet confirmé jamais parti : son chat est aussi programmé pour l’archivage', async () => {
    const chat = (await call('Inès', 'GET', `/rides/${tuesdayId}/conversation`)).json<Conversation>();
    await ctx.app.services!.chat.applyRetention();
    const { rows } = await ctx.database.pool.query<{ d: Date | null }>('SELECT delete_after AS d FROM conversations WHERE id = $1', [chat.id]);
    expect(rows[0]!.d).not.toBeNull();
  });
});
