import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/**
 * Critères de M5 : annulations précoce, tardive et absence (pénalité dégressive, notification,
 * remplaçant), notes croisées, score de fiabilité, litiges niveau 1 puis 2, signalements.
 */
let ctx: TestContext;
const tokens = new Map<string, Tokens>();
const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;
const SUPPORT = 'contact@uni-moov.fr';

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

async function call(firstName: string, method: 'GET' | 'POST', url: string, payload?: object) {
  return ctx.app.inject({
    method,
    url: `/api/v1${url}`,
    headers: bearer(await login(firstName)),
    ...(payload ? { payload } : {}),
  });
}

const code = (response: { json: <T>() => T }) => response.json<{ error: { code: string } }>().error.code;

interface Reliability {
  score: number;
  completedRides: number;
  cancellations: { early: number; medium: number; late: number };
  noShows: number;
  ratingsCount: number;
  averageStars: number | null;
  events: { kind: string; rideId: string; disputeReason: string | null }[];
}
const reliability = async (name: string) => (await call(name, 'GET', '/me/reliability')).json<Reliability>();

interface Proposal {
  id: string;
  day: string;
  direction: string;
  rideStatus: string;
}
async function proposals(name: string): Promise<Proposal[]> {
  return (await call(name, 'GET', '/proposals?week=2026-W43')).json<{ proposals: Proposal[] }>().proposals;
}
const rideOf = async (day: string, direction: string) => (await proposals('Léa')).find((p) => p.day === day && p.direction === direction)!.id;

let monTo: string;
let monFrom: string;
let tueTo: string;
let wedTo: string;

beforeAll(async () => {
  // Dimanche midi à Paris.
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await ctx.app.ready();
  await runSeed(ctx.database.db, { today: '2026-10-19' });
  monTo = await rideOf('2026-10-19', 'to_campus');
  monFrom = await rideOf('2026-10-19', 'from_campus');
  tueTo = await rideOf('2026-10-20', 'to_campus');
  wedTo = await rideOf('2026-10-21', 'to_campus');
  const accept = async (name: string, rideId: string) =>
    expect((await call(name, 'POST', `/proposals/${rideId}/accept`)).statusCode).toBe(200);
  for (const name of ['Léa', 'Hugo', 'Inès']) await accept(name, monTo);
  expect((await call('Chloé', 'POST', `/proposals/${monTo}/decline`)).statusCode).toBe(204);
  for (const name of ['Léa', 'Hugo', 'Chloé', 'Inès']) await accept(name, monFrom);
  for (const name of ['Léa', 'Hugo', 'Inès']) await accept(name, tueTo);
  for (const name of ['Léa', 'Chloé']) await accept(name, wedTo);
  const topup = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/wallet/topups',
    headers: { ...bearer(await login('Inès')), 'idempotency-key': 'recharge-ines-m5-01' },
    payload: { amountCents: 2000 },
  });
  expect(topup.statusCode).toBe(201);
});
afterAll(async () => {
  await ctx.close();
});

describe('annulations (cahier §8)', () => {
  it('le palier de pénalité est annoncé avant de confirmer', async () => {
    // Mercredi 8 h à Paris, soit 68 h plus tard : précoce. Lundi 8 h, 20 h plus tard : moyenne.
    expect((await call('Chloé', 'GET', `/rides/${wedTo}/cancellation`)).json()).toEqual({ role: 'passenger', tier: 'early' });
    expect((await call('Hugo', 'GET', `/rides/${monTo}/cancellation`)).json()).toEqual({ role: 'passenger', tier: 'medium' });
    // Sans acceptation, ce n'est pas une annulation mais un refus.
    expect(code(await call('Chloé', 'GET', `/rides/${monTo}/cancellation`))).toBe('not_accepted');
    expect((await call('Nathan', 'GET', `/rides/${monTo}/cancellation`)).statusCode).toBe(404);
  });

  it('annulation précoce d’un passager : pénalité légère, conducteur prévenu, trajet de nouveau ouvert', async () => {
    ctx.notifier.sent.length = 0;
    const before = await reliability('Chloé');
    expect(before.score).toBe(0.8);
    const response = await call('Chloé', 'POST', `/rides/${wedTo}/cancel`);
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ tier: 'early' });
    const after = await reliability('Chloé');
    expect(after.cancellations).toEqual({ early: 1, medium: 0, late: 0 });
    expect(after.score).toBeLessThan(0.8);
    expect(after.score).toBeGreaterThan(0.7);
    expect(ctx.notifier.sent).toContainEqual({
      userIds: [user('Léa').id],
      event: { type: 'ride_cancelled', rideId: wedTo, by: 'passenger' },
    });
    // Plus aucun passager accepté : le trajet redevient une proposition, Léa reste engagée.
    expect((await proposals('Léa')).find((p) => p.id === wedTo)!.rideStatus).toBe('proposed');
    expect(code(await call('Chloé', 'POST', `/rides/${wedTo}/cancel`))).toBe('not_accepted');
  });

  it('place libérée par un passager : proposée au passager disponible le mieux placé', async () => {
    const nathanWed = (await proposals('Nathan')).find((p) => p.day === '2026-10-21' && p.direction === 'to_campus')!.id;
    for (const name of ['Nathan', 'Manon']) expect((await call(name, 'POST', `/proposals/${nathanWed}/accept`)).statusCode).toBe(200);
    ctx.notifier.sent.length = 0;
    expect((await call('Manon', 'POST', `/rides/${nathanWed}/cancel`)).statusCode).toBe(200);
    // Chloé, libre ce matin-là depuis son annulation, est dans le détour de Nathan.
    expect(ctx.notifier.sent).toContainEqual({
      userIds: [user('Chloé').id],
      event: { type: 'replacement_proposed', rideId: nathanWed },
    });
    const chloe = (await proposals('Chloé')).find((p) => p.id === nathanWed);
    expect(chloe).toMatchObject({ rideStatus: 'proposed' });
  });

  it('annulation moyenne : plus lourde que la précoce ; le passager perd l’accès au trajet', async () => {
    ctx.notifier.sent.length = 0;
    expect((await call('Hugo', 'POST', `/rides/${monTo}/cancel`)).json()).toEqual({ tier: 'medium' });
    const hugo = await reliability('Hugo');
    expect(hugo.cancellations.medium).toBe(1);
    expect(hugo.score).toBeLessThan((await reliability('Chloé')).score);
    expect(hugo.events[0]).toMatchObject({ kind: 'cancel_medium', rideId: monTo, disputeReason: 'cancellation_penalty' });
    expect(ctx.notifier.sent[0]!.userIds.sort()).toEqual([user('Inès').id, user('Léa').id].sort());
    expect((await call('Hugo', 'GET', `/rides/${monTo}`)).statusCode).toBe(403);
    expect((await call('Inès', 'GET', `/rides/${monTo}`)).json<{ status: string }>().status).toBe('confirmed');
  });
});

describe('trajet mené à bien et absences (cahier §7, §9)', () => {
  it('lundi matin : Inès présente, trajet clôturé, chacun gagne un trajet mené à bien', async () => {
    ctx.clock.now = new Date('2026-10-19T05:30:00Z');
    expect((await call('Léa', 'POST', `/rides/${monTo}/start`)).statusCode).toBe(204);
    expect(await ctx.app.services!.lifecycle.validatePresence(monTo, user('Inès').id)).toBe('paid');
    expect((await call('Léa', 'POST', `/rides/${monTo}/finish`)).statusCode).toBe(204);
    expect((await reliability('Léa')).completedRides).toBe(1);
    expect((await reliability('Inès')).completedRides).toBe(1);
  });

  it('notes croisées : conducteur ↔ passagers présents, une fois, jamais un absent ou un tiers', async () => {
    const ines = (await call('Inès', 'GET', `/rides/${monTo}/ratings`)).json<{ open: boolean; people: { userId: string; stars: number | null }[] }>();
    expect(ines.open).toBe(true);
    expect(ines.people).toEqual([expect.objectContaining({ userId: user('Léa').id, stars: null, role: 'driver' })]);

    const scoreBefore = (await reliability('Léa')).score;
    expect((await call('Inès', 'POST', `/rides/${monTo}/ratings`, { ratedUserId: user('Léa').id, stars: 5 })).statusCode).toBe(204);
    expect(code(await call('Inès', 'POST', `/rides/${monTo}/ratings`, { ratedUserId: user('Léa').id, stars: 1 }))).toBe('already_rated');
    expect((await reliability('Léa')).score).toBeGreaterThan(scoreBefore);
    expect((await reliability('Léa')).averageStars).toBe(5);

    expect((await call('Léa', 'POST', `/rides/${monTo}/ratings`, { ratedUserId: user('Inès').id, stars: 4 })).statusCode).toBe(204);
    expect(code(await call('Léa', 'POST', `/rides/${monTo}/ratings`, { ratedUserId: user('Hugo').id, stars: 1 }))).toBe('not_rateable');
    expect((await call('Hugo', 'GET', `/rides/${monTo}/ratings`)).statusCode).toBe(403);
    expect((await call('Nathan', 'POST', `/rides/${monTo}/ratings`, { ratedUserId: user('Léa').id, stars: 1 })).statusCode).toBe(403);
    expect((await call('Inès', 'POST', `/rides/${monTo}/ratings`, { ratedUserId: user('Léa').id, stars: 6 })).statusCode).toBe(400);
    const lea = (await call('Léa', 'GET', `/rides/${monTo}/ratings`)).json<{ people: { userId: string; stars: number | null }[] }>();
    expect(lea.people).toEqual([expect.objectContaining({ userId: user('Inès').id, stars: 4 })]);
  });

  it('lundi soir : Hugo monté sans validation GPS et Chloé jamais vue sont comptés absents', async () => {
    ctx.clock.now = new Date('2026-10-19T15:00:00Z');
    expect((await call('Léa', 'POST', `/rides/${monFrom}/start`)).statusCode).toBe(204);
    expect((await call('Léa', 'POST', `/rides/${monFrom}/participants/${user('Hugo').id}/picked-up`)).statusCode).toBe(204);
    expect(await ctx.app.services!.lifecycle.validatePresence(monFrom, user('Inès').id)).toBe('paid');
    const hugoBefore = (await reliability('Hugo')).score;
    expect((await call('Inès', 'POST', `/rides/${monFrom}/finish`)).statusCode).toBe(204);

    const hugo = await reliability('Hugo');
    expect(hugo.noShows).toBe(1);
    expect(hugo.score).toBeLessThan(hugoBefore);
    expect((await reliability('Chloé')).noShows).toBe(1);
    // L'absence pèse plus qu'une annulation précoce.
    expect((await reliability('Chloé')).events[0]).toMatchObject({ kind: 'no_show', disputeReason: 'marked_absent' });
    // L'absent garde l'accès au trajet clôturé, pour un éventuel litige.
    expect((await call('Hugo', 'GET', `/rides/${monFrom}`)).json<{ myStatus: string }>().myStatus).toBe('absent');
  });
});

interface Dispute {
  id: string;
  level: number;
  decision: string;
  explanation: string;
}

describe('litiges (cahier §10)', () => {
  it('niveau 1 : pénalité d’annulation conforme aux horodatages serveur, maintenue', async () => {
    const response = await call('Hugo', 'POST', `/rides/${monTo}/disputes`, { reason: 'cancellation_penalty' });
    expect(response.statusCode).toBe(201);
    expect(response.json<Dispute>()).toMatchObject({ level: 1, decision: 'upheld', explanation: 'penalty_matches_timestamps' });
    expect(code(await call('Hugo', 'POST', `/rides/${monTo}/disputes`, { reason: 'cancellation_penalty' }))).toBe('dispute_exists');
  });

  it('niveau 1 : absent sans aucune preuve de présence, maintenu ; contesté, passe à l’équipe', async () => {
    const opened = (await call('Chloé', 'POST', `/rides/${monFrom}/disputes`, { reason: 'marked_absent' })).json<Dispute>();
    expect(opened).toMatchObject({ level: 1, decision: 'upheld', explanation: 'no_presence_evidence' });
    expect(ctx.mail.lastTo(SUPPORT)).toBeUndefined();

    const escalated = await call('Chloé', 'POST', `/disputes/${opened.id}/escalate`, { message: 'J’étais au point de rendez-vous.' });
    expect(escalated.json<Dispute>()).toMatchObject({ level: 2, decision: 'escalated' });
    const mail = ctx.mail.lastTo(SUPPORT)!;
    expect(mail.subject).toContain(opened.id);
    expect(mail.text).toContain('J’étais au point de rendez-vous.');
    expect(mail.text).toContain(user('Chloé').email);
    // Rejeu : pas de second mail.
    const count = ctx.mail.sent.filter((m) => m.to === SUPPORT).length;
    const replay = await call('Chloé', 'POST', `/disputes/${opened.id}/escalate`);
    expect(replay.json<Dispute>().level, replay.body).toBe(2);
    expect(ctx.mail.sent.filter((m) => m.to === SUPPORT)).toHaveLength(count);
    expect((await call('Hugo', 'POST', `/disputes/${opened.id}/escalate`)).statusCode).toBe(404);
  });

  it('déclarations contradictoires (monté mais pas de validation GPS) : directement à l’équipe', async () => {
    const opened = (await call('Hugo', 'POST', `/rides/${monFrom}/disputes`, { reason: 'marked_absent' })).json<Dispute>();
    expect(opened).toMatchObject({ level: 2, decision: 'escalated', explanation: 'driver_confirmed_boarding' });
    expect(ctx.mail.lastTo(SUPPORT)!.subject).toContain(opened.id);
    const list = (await call('Hugo', 'GET', `/rides/${monFrom}/disputes`)).json<{ disputes: Dispute[] }>();
    expect(list.disputes.map((d) => d.id)).toEqual([opened.id]);
  });

  it('motif sans rapport ou hors trajet : refusé', async () => {
    expect(code(await call('Inès', 'POST', `/rides/${monFrom}/disputes`, { reason: 'cancellation_penalty' }))).toBe('dispute_not_applicable');
    expect((await call('Nathan', 'POST', `/rides/${monFrom}/disputes`, { reason: 'payment' })).statusCode).toBe(403);
    expect((await call('Inès', 'POST', `/rides/${monFrom}/disputes`, { reason: 'inconnu' })).statusCode).toBe(400);
  });
});

describe('annulation tardive du conducteur', () => {
  it('pénalité forte pour lui seul, passagers prévenus et relancés', async () => {
    ctx.clock.now = new Date('2026-10-20T05:00:00Z');
    ctx.notifier.sent.length = 0;
    const ines = (await reliability('Inès')).score;
    const leaBefore = await reliability('Léa');
    expect((await call('Léa', 'POST', `/rides/${tueTo}/cancel`)).json()).toEqual({ tier: 'late' });
    const lea = await reliability('Léa');
    expect(lea.cancellations.late).toBe(1);
    expect(lea.score).toBeLessThan(leaBefore.score);
    expect((await reliability('Inès')).score).toBe(ines);
    expect(ctx.notifier.sent[0]).toEqual({
      userIds: expect.arrayContaining([user('Hugo').id, user('Inès').id]) as string[],
      event: { type: 'ride_cancelled', rideId: tueTo, by: 'driver' },
    });
    expect((await proposals('Inès')).find((p) => p.id === tueTo)!.rideStatus).toBe('cancelled');
    // Le trajet annulé par le conducteur n'ouvre pas de litige à ses passagers (rien à contester).
    expect((await call('Inès', 'POST', `/rides/${tueTo}/disputes`, { reason: 'other' })).statusCode).toBe(403);
    // Remplaçant : chaque passager reçoit une autre proposition pour ce créneau, et en est prévenu.
    for (const name of ['Hugo', 'Inès']) {
      const other = (await proposals(name)).find((p) => p.day === '2026-10-20' && p.direction === 'to_campus' && p.id !== tueTo);
      expect(other?.rideStatus).toBe('proposed');
      expect(ctx.notifier.sent).toContainEqual({ userIds: [user(name).id], event: { type: 'replacement_proposed', rideId: other!.id } });
    }
  });
});

describe('signalements', () => {
  it('seulement une personne croisée sur un trajet, transmis à l’équipe, limité par jour', async () => {
    const response = await call('Hugo', 'POST', '/reports', { targetUserId: user('Léa').id, reason: 'dangerous_driving', message: 'Vitesse excessive.' });
    expect(response.statusCode).toBe(201);
    const id = response.json<{ id: string }>().id;
    expect(ctx.mail.lastTo(SUPPORT)!.subject).toBe(`Signalement ${id}`);
    expect(ctx.mail.lastTo(SUPPORT)!.text).toContain('Vitesse excessive.');

    // Jamais croisé, ou soi-même.
    expect((await call('Hugo', 'POST', '/reports', { targetUserId: user('Théo').id, reason: 'other' })).statusCode).toBe(404);
    expect((await call('Hugo', 'POST', '/reports', { targetUserId: user('Hugo').id, reason: 'other' })).statusCode).toBe(400);

    for (let i = 0; i < 4; i++) {
      expect((await call('Hugo', 'POST', '/reports', { targetUserId: user('Inès').id, reason: 'other' })).statusCode).toBe(201);
    }
    expect(code(await call('Hugo', 'POST', '/reports', { targetUserId: user('Inès').id, reason: 'other' }))).toBe('report_limit');
  });
});

describe('fenêtres de temps', () => {
  it('notes fermées après la fenêtre configurée, litiges après la leur', async () => {
    ctx.clock.now = new Date('2026-10-27T07:00:00Z');
    const ratings = (await call('Inès', 'GET', `/rides/${monTo}/ratings`)).json<{ open: boolean }>();
    expect(ratings.open).toBe(false);
    expect(code(await call('Léa', 'POST', `/rides/${monFrom}/ratings`, { ratedUserId: user('Inès').id, stars: 5 }))).toBe('rating_closed');
    ctx.clock.now = new Date('2026-11-03T07:00:00Z');
    expect(code(await call('Inès', 'POST', `/rides/${monFrom}/disputes`, { reason: 'payment' }))).toBe('dispute_closed');
    expect((await reliability('Hugo')).events.every((e) => e.disputeReason === null)).toBe(true);
  });

  it('pénalités sorties de la fenêtre : la tâche quotidienne rétablit le score, même sans nouveau trajet', async () => {
    const score = async () =>
      Number((await ctx.database.pool.query<{ s: string }>('SELECT reliability_score AS s FROM users WHERE id = $1', [user('Hugo').id])).rows[0]!.s);
    expect(await score()).toBeLessThan(0.8);
    // 180 jours après l'absence du 19 octobre.
    ctx.clock.now = new Date('2027-04-19T12:00:00Z');
    expect(await ctx.app.services!.trust.refreshExpired()).toBeGreaterThan(0);
    expect(await score()).toBe(0.8);
  });
});
