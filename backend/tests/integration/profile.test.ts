import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { bearer, setupTestContext, signUp, type TestContext, type Tokens } from './helpers.js';

let ctx: TestContext;
let lea: Tokens;
let hugo: Tokens;
let hugoId: string;

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-11-04T09:00:00Z')); // un mercredi
  lea = await signUp(ctx, 'lea@etu.univ-smb.fr');
  ctx.clock.advance(61_000);
  hugo = await signUp(ctx, 'hugo@etu.univ-smb.fr', { firstName: 'Hugo', lastName: 'Bernard' });
  hugoId = (await ctx.app.inject({ method: 'GET', url: '/api/v1/me', headers: bearer(hugo) })).json<{ id: string }>()
    .id;
});
afterAll(async () => {
  await ctx.close();
});

const call = (tokens: Tokens, method: 'GET' | 'PUT' | 'PATCH' | 'POST' | 'DELETE', url: string, payload?: object) =>
  ctx.app.inject({ method, url: `/api/v1${url}`, headers: bearer(tokens), ...(payload ? { payload } : {}) });

describe('adresse', () => {
  it('géocode côté serveur, calcule le secteur et sort du mode découverte', async () => {
    const response = await call(lea, 'PUT', '/me/address', { address: '12 rue de la Paix, Annecy' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      home: { address: '12 Rue de la Paix 74000 Annecy', lat: 45.9003, lon: 6.1251 },
      discoveryMode: false,
    });
    expect(response.json<{ home: { sector: string } }>().home.sector).toMatch(/^\d+:\d+$/);
  });

  it('adresse introuvable : 422', async () => {
    const response = await call(lea, 'PUT', '/me/address', { address: 'nulle part 99999' });
    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({ error: { code: 'address_not_found' } });
  });
});

describe('véhicule et rôle', () => {
  it('sans véhicule, impossible de conduire', async () => {
    const response = await call(lea, 'PATCH', '/me/preferences', { roleMode: 'auto' });
    expect(response.statusCode).toBe(409);
    expect(response.json()).toMatchObject({ error: { code: 'vehicle_required' } });
  });

  it('déclarer un véhicule ouvre le mode automatique', async () => {
    const vehicle = await call(lea, 'PUT', '/me/vehicle', {
      consumptionLPer100km: 5.84,
      defaultSeats: 3,
      maxDetourMinutes: 10,
    });
    expect(vehicle.statusCode).toBe(200);
    expect(vehicle.json()).toMatchObject({
      vehicle: { consumptionLPer100km: 5.8, defaultSeats: 3, maxDetourMinutes: 10 },
    });
    const prefs = await call(lea, 'PATCH', '/me/preferences', { roleMode: 'auto', defaultNavApp: 'waze' });
    expect(prefs.json()).toMatchObject({ roleMode: 'auto', defaultNavApp: 'waze' });
  });

  it('modifier le véhicule le remplace (un seul par personne)', async () => {
    await call(lea, 'PUT', '/me/vehicle', { consumptionLPer100km: 6, defaultSeats: 4, maxDetourMinutes: 15 });
    const { rows } = await ctx.database.pool.query<{ n: number }>('SELECT count(*)::int AS n FROM vehicles');
    expect(rows[0]?.n).toBe(1);
  });

  it('retirer le véhicule repasse en passager', async () => {
    expect((await call(lea, 'DELETE', '/me/vehicle')).statusCode).toBe(204);
    const me = await call(lea, 'GET', '/me');
    expect(me.json()).toMatchObject({ vehicle: null, roleMode: 'always_passenger' });
    expect((await call(lea, 'DELETE', '/me/vehicle')).statusCode).toBe(404);
  });

  it('refuse un véhicule hors bornes', async () => {
    const response = await call(lea, 'PUT', '/me/vehicle', {
      consumptionLPer100km: 50,
      defaultSeats: 12,
      maxDetourMinutes: 10,
    });
    expect(response.statusCode).toBe(400);
  });
});

describe('onboarding : quitter et reprendre', () => {
  it('reprend à la bonne étape après une nouvelle connexion', async () => {
    const email = 'reprise@etu.univ-smb.fr';
    ctx.clock.advance(61_000);
    const first = await signUp(ctx, email);
    await call(first, 'PUT', '/me/onboarding/profile', { status: 'done' });
    const skipped = await call(first, 'PUT', '/me/onboarding/vehicle', { status: 'skipped' });
    expect(skipped.json()).toMatchObject({ onboarding: { nextStep: 'preferences', completed: false } });

    // L'utilisateur quitte l'app, puis se reconnecte.
    await ctx.app.inject({ method: 'POST', url: '/api/v1/auth/logout', payload: { refreshToken: first.refreshToken } });
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { universityEmail: email, password: 'motdepasse-solide' },
    });
    const again = login.json<Tokens>();
    const me = await call(again, 'GET', '/me');
    expect(me.json()).toMatchObject({
      onboarding: { steps: { profile: 'done', vehicle: 'skipped' }, nextStep: 'preferences', completed: false },
    });

    await call(again, 'PUT', '/me/onboarding/preferences', { status: 'done' });
    const done = await call(again, 'PUT', '/me/onboarding/calendar', { status: 'skipped' });
    expect(done.json()).toMatchObject({ onboarding: { nextStep: null, completed: true } });
  });

  it('refuse une étape inconnue', async () => {
    expect((await call(lea, 'PUT', '/me/onboarding/paiement', { status: 'done' })).statusCode).toBe(400);
  });
});

describe('pauses', () => {
  it('une pause en cours met l’utilisateur en pause aujourd’hui', async () => {
    const created = await call(hugo, 'POST', '/me/pauses', {
      startsOn: '2026-11-02',
      endsOn: '2027-06-30',
      recurrence: 'weekly:2',
    });
    expect(created.statusCode).toBe(201);
    expect((await call(hugo, 'GET', '/me')).json()).toMatchObject({ pausedToday: true });
    ctx.clock.advance(7 * 86_400_000); // semaine suivante : pas de pause
    expect((await call(hugo, 'GET', '/me')).json()).toMatchObject({ pausedToday: false });
  });

  it('refuse une pause à l’envers ou trop longue', async () => {
    const reversed = await call(hugo, 'POST', '/me/pauses', { startsOn: '2026-12-10', endsOn: '2026-12-01', recurrence: null });
    expect(reversed.json()).toMatchObject({ error: { code: 'invalid_pause' } });
    const tooLong = await call(hugo, 'POST', '/me/pauses', { startsOn: '2026-01-01', endsOn: '2028-01-01', recurrence: null });
    expect(tooLong.statusCode).toBe(400);
    const badRecurrence = await call(hugo, 'POST', '/me/pauses', {
      startsOn: '2026-12-01',
      endsOn: '2026-12-10',
      recurrence: 'daily',
    });
    expect(badRecurrence.statusCode).toBe(400);
  });
});

describe('contrôle d’accès', () => {
  it('un utilisateur ne voit ni ne supprime les pauses d’un autre', async () => {
    const hugoPauses = (await call(hugo, 'GET', '/me/pauses')).json<{ pauses: { id: string }[] }>().pauses;
    expect(hugoPauses.length).toBeGreaterThan(0);
    expect((await call(lea, 'GET', '/me/pauses')).json()).toEqual({ pauses: [] });
    const attempt = await call(lea, 'DELETE', `/me/pauses/${hugoPauses[0]!.id}`);
    expect(attempt.statusCode).toBe(404);
    expect((await call(hugo, 'GET', '/me/pauses')).json<{ pauses: unknown[] }>().pauses).toHaveLength(hugoPauses.length);
  });

  it('PATCH /me ne permet pas de changer son mail', async () => {
    const response = await call(lea, 'PATCH', '/me', { firstName: 'Léna', universityEmail: 'pirate@etu.univ-smb.fr' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ firstName: 'Léna', universityEmail: 'lea@etu.univ-smb.fr' });
  });

  it('le profil public n’expose que prénom, photo et score', async () => {
    const response = await call(lea, 'GET', `/users/${hugoId}/public`);
    expect(response.statusCode).toBe(200);
    expect(Object.keys(response.json()).sort()).toEqual(['firstName', 'id', 'photoUrl', 'reliabilityScore']);
    expect(JSON.stringify(response.json())).not.toMatch(/Bernard|hugo@|lat|address/);
  });

  it('profil public : exige un JWT et renvoie 404 pour un inconnu', async () => {
    expect((await ctx.app.inject({ method: 'GET', url: `/api/v1/users/${hugoId}/public` })).statusCode).toBe(401);
    expect((await call(lea, 'GET', '/users/00000000-0000-4000-8000-000000000999/public')).statusCode).toBe(404);
  });

  it('un compte supprimé ne peut plus utiliser son jeton', async () => {
    await ctx.database.pool.query("UPDATE users SET deleted_at = now() WHERE university_email = 'hugo@etu.univ-smb.fr'");
    expect((await call(hugo, 'GET', '/me')).statusCode).toBe(401);
    const refresh = await ctx.app.inject({
      method: 'POST',
      url: '/api/v1/auth/refresh',
      payload: { refreshToken: hugo.refreshToken },
    });
    expect(refresh.statusCode).toBe(401);
  });
});
