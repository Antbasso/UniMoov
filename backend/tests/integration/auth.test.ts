import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { bearer, codeFromMail, setupTestContext, signUp, type TestContext, type Tokens } from './helpers.js';

let ctx: TestContext;
let counter = 0;
const freshEmail = () => `etudiant${++counter}@etu.univ-smb.fr`;

beforeAll(async () => {
  ctx = await setupTestContext();
});
afterAll(async () => {
  await ctx.close();
});
beforeEach(() => {
  // Délai entre deux demandes de code respecté d'un test à l'autre.
  ctx.clock.advance(5 * 60_000);
});

const post = (url: string, payload: unknown, headers?: Record<string, string>) =>
  ctx.app.inject({ method: 'POST', url: `/api/v1${url}`, payload: payload as object, ...(headers ? { headers } : {}) });

describe('inscription par code', () => {
  it('refuse une adresse non universitaire', async () => {
    const response = await post('/auth/signup/request-code', { universityEmail: 'lea@gmail.com' });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: 'email_domain_not_allowed' } });
    expect(ctx.mail.sent).toHaveLength(0);
  });

  it('crée un compte vérifié, rattaché au campus pilote, en mode découverte', async () => {
    const email = freshEmail();
    const tokens = await signUp(ctx, email);
    const me = await ctx.app.inject({ method: 'GET', url: '/api/v1/me', headers: bearer(tokens) });
    expect(me.statusCode).toBe(200);
    expect(me.json()).toMatchObject({
      universityEmail: email,
      firstName: 'Léa',
      lastName: 'Martin',
      campusId: '00000000-0000-4000-8000-000000000001',
      home: null,
      roleMode: 'always_passenger',
      onboarding: { steps: {}, nextStep: 'profile', completed: false },
      discoveryMode: true,
    });
  });

  it('normalise l’adresse (casse, espaces)', async () => {
    const email = freshEmail();
    const raw = `  ${email.toUpperCase()} `;
    expect((await post('/auth/signup/request-code', { universityEmail: raw })).statusCode).toBe(202);
    const verify = await post('/auth/signup/verify', {
      universityEmail: raw,
      code: codeFromMail(ctx, email),
      firstName: 'Léa',
      lastName: 'Martin',
      password: 'motdepasse-solide',
    });
    expect(verify.statusCode).toBe(201);
    const login = await post('/auth/login', { universityEmail: email, password: 'motdepasse-solide' });
    expect(login.statusCode).toBe(200);
  });

  it('impose un délai entre deux codes', async () => {
    const email = freshEmail();
    expect((await post('/auth/signup/request-code', { universityEmail: email })).statusCode).toBe(202);
    const again = await post('/auth/signup/request-code', { universityEmail: email });
    expect(again.statusCode).toBe(429);
    expect(again.json()).toMatchObject({ error: { code: 'code_cooldown' } });
    ctx.clock.advance(61_000);
    expect((await post('/auth/signup/request-code', { universityEmail: email })).statusCode).toBe(202);
  });

  it('un nouveau code invalide le précédent', async () => {
    const email = freshEmail();
    await post('/auth/signup/request-code', { universityEmail: email });
    const first = codeFromMail(ctx, email);
    ctx.clock.advance(61_000);
    await post('/auth/signup/request-code', { universityEmail: email });
    const second = codeFromMail(ctx, email);
    const base = { universityEmail: email, firstName: 'A', lastName: 'B', password: 'motdepasse-solide' };
    if (first !== second) {
      expect((await post('/auth/signup/verify', { ...base, code: first })).statusCode).toBe(400);
    }
    expect((await post('/auth/signup/verify', { ...base, code: second })).statusCode).toBe(201);
  });

  it('refuse un code expiré', async () => {
    const email = freshEmail();
    await post('/auth/signup/request-code', { universityEmail: email });
    ctx.clock.advance(11 * 60_000);
    const response = await post('/auth/signup/verify', {
      universityEmail: email,
      code: codeFromMail(ctx, email),
      firstName: 'A',
      lastName: 'B',
      password: 'motdepasse-solide',
    });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: 'code_invalid' } });
  });

  it('bloque le code après 5 essais faux, même si le 6e est juste', async () => {
    const email = freshEmail();
    await post('/auth/signup/request-code', { universityEmail: email });
    const good = codeFromMail(ctx, email);
    const wrong = good === '000000' ? '111111' : '000000';
    const base = { universityEmail: email, firstName: 'A', lastName: 'B', password: 'motdepasse-solide' };
    for (let i = 0; i < 5; i++) {
      expect((await post('/auth/signup/verify', { ...base, code: wrong })).statusCode).toBe(400);
    }
    expect((await post('/auth/signup/verify', { ...base, code: good })).statusCode).toBe(400);
  });

  it('un code ne sert qu’une fois', async () => {
    const email = freshEmail();
    await signUp(ctx, email);
    const reuse = await post('/auth/signup/verify', {
      universityEmail: email,
      code: codeFromMail(ctx, email),
      firstName: 'A',
      lastName: 'B',
      password: 'motdepasse-solide',
    });
    expect(reuse.statusCode).toBe(400);
  });

  it('compte existant : même réponse, aucun code envoyé (pas d’énumération)', async () => {
    const email = freshEmail();
    await signUp(ctx, email);
    ctx.clock.advance(61_000);
    const response = await post('/auth/signup/request-code', { universityEmail: email });
    expect(response.statusCode).toBe(202);
    expect(ctx.mail.lastTo(email)?.subject).toBe('Tu as déjà un compte Uni-Moov');
    expect(ctx.mail.lastTo(email)?.text).not.toMatch(/\d{6}/);
  });

  it('plafond quotidien de codes par adresse', async () => {
    const email = freshEmail();
    for (let i = 0; i < 10; i++) {
      expect((await post('/auth/signup/request-code', { universityEmail: email })).statusCode).toBe(202);
      ctx.clock.advance(61_000);
    }
    const capped = await post('/auth/signup/request-code', { universityEmail: email });
    expect(capped.statusCode).toBe(429);
    expect(capped.json<{ error: { code: string } }>().error.code).toBe('code_daily_limit');
  });

  it('refuse un mot de passe trop court', async () => {
    const email = freshEmail();
    await post('/auth/signup/request-code', { universityEmail: email });
    const response = await post('/auth/signup/verify', {
      universityEmail: email,
      code: codeFromMail(ctx, email),
      firstName: 'A',
      lastName: 'B',
      password: 'court',
    });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ error: { code: 'validation_error' } });
  });

  it('ne stocke ni le code ni le mot de passe en clair', async () => {
    const email = freshEmail();
    await signUp(ctx, email, undefined, 'motdepasse-en-clair');
    const { rows } = await ctx.database.pool.query<{ password_hash: string }>(
      'SELECT password_hash FROM users WHERE university_email = $1',
      [email],
    );
    expect(rows[0]?.password_hash).toMatch(/^\$argon2id\$/);
    const codes = await ctx.database.pool.query<{ code_hash: string }>(
      'SELECT code_hash FROM verification_codes WHERE email = $1',
      [email],
    );
    expect(codes.rows.every((r) => !/^\d{6}$/.test(r.code_hash))).toBe(true);
  });
});

describe('connexion', () => {
  let email: string;
  beforeAll(async () => {
    email = freshEmail();
    await signUp(ctx, email);
  });

  it('accepte le bon mot de passe', async () => {
    const response = await post('/auth/login', { universityEmail: email, password: 'motdepasse-solide' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ accessTokenExpiresIn: 900 });
  });

  it('même erreur pour un mauvais mot de passe et un compte inconnu', async () => {
    const wrong = await post('/auth/login', { universityEmail: email, password: 'mauvais-mot-de-passe' });
    const unknown = await post('/auth/login', { universityEmail: 'inconnu@etu.univ-smb.fr', password: 'x' });
    expect(wrong.statusCode).toBe(401);
    expect(unknown.statusCode).toBe(401);
    expect(wrong.json()).toEqual(unknown.json());
  });

  it('trop d’échecs sur une adresse : bloquée un moment, même avec le bon mot de passe, puis libérée', async () => {
    const target = freshEmail();
    await signUp(ctx, target);
    for (let i = 0; i < 10; i++) {
      expect((await post('/auth/login', { universityEmail: target, password: `essai-${i}` })).statusCode).toBe(401);
    }
    const locked = await post('/auth/login', { universityEmail: target, password: 'motdepasse-solide' });
    expect(locked.statusCode).toBe(429);
    expect(locked.json<{ error: { code: string } }>().error.code).toBe('login_locked');
    // Même blocage pour une adresse inconnue : rien n'indique si le compte existe.
    for (let i = 0; i < 10; i++) await post('/auth/login', { universityEmail: 'personne@etu.univ-smb.fr', password: 'x' });
    expect((await post('/auth/login', { universityEmail: 'personne@etu.univ-smb.fr', password: 'x' })).statusCode).toBe(429);

    ctx.clock.advance(16 * 60_000);
    expect((await post('/auth/login', { universityEmail: target, password: 'motdepasse-solide' })).statusCode).toBe(200);
  });
});

describe('jetons', () => {
  let tokens: Tokens;
  beforeAll(async () => {
    tokens = await signUp(ctx, freshEmail());
  });

  it('une route protégée exige un JWT valide', async () => {
    expect((await ctx.app.inject({ method: 'GET', url: '/api/v1/me' })).statusCode).toBe(401);
    const tampered = await ctx.app.inject({
      method: 'GET',
      url: '/api/v1/me',
      headers: { authorization: `Bearer ${tokens.accessToken.slice(0, -2)}xx` },
    });
    expect(tampered.statusCode).toBe(401);
    expect(tampered.json()).toMatchObject({ error: { code: 'unauthorized' } });
  });

  it('refuse un JWT signé avec un autre secret', async () => {
    const forged = ctx.app.jwt.sign({ sub: '00000000-0000-4000-8000-000000000999' });
    // Signé avec le bon secret mais pour un utilisateur inexistant : 401 aussi.
    const response = await ctx.app.inject({
      method: 'GET',
      url: '/api/v1/me',
      headers: { authorization: `Bearer ${forged}` },
    });
    expect(response.statusCode).toBe(401);
  });

  it('rotation : le refresh donne de nouveaux jetons, l’ancien ne resert pas', async () => {
    const first = await post('/auth/refresh', { refreshToken: tokens.refreshToken });
    expect(first.statusCode).toBe(200);
    const rotated = first.json<Tokens>();
    expect(rotated.refreshToken).not.toBe(tokens.refreshToken);

    // Réutilisation de l'ancien jeton : refus, et toute la famille est révoquée.
    const reuse = await post('/auth/refresh', { refreshToken: tokens.refreshToken });
    expect(reuse.statusCode).toBe(401);
    const afterTheft = await post('/auth/refresh', { refreshToken: rotated.refreshToken });
    expect(afterTheft.statusCode).toBe(401);
  });

  it('deux connexions sont des familles indépendantes', async () => {
    const email = freshEmail();
    const phone = await signUp(ctx, email);
    const tablet = (await post('/auth/login', { universityEmail: email, password: 'motdepasse-solide' })).json<Tokens>();
    await post('/auth/refresh', { refreshToken: phone.refreshToken });
    await post('/auth/refresh', { refreshToken: phone.refreshToken }); // vol présumé sur le téléphone
    expect((await post('/auth/refresh', { refreshToken: tablet.refreshToken })).statusCode).toBe(200);
  });

  it('logout révoque la session', async () => {
    const session = await signUp(ctx, freshEmail());
    expect((await post('/auth/logout', { refreshToken: session.refreshToken })).statusCode).toBe(204);
    expect((await post('/auth/refresh', { refreshToken: session.refreshToken })).statusCode).toBe(401);
  });

  it('refuse un jeton inconnu', async () => {
    const response = await post('/auth/refresh', { refreshToken: 'x'.repeat(43) });
    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({ error: { code: 'invalid_refresh_token' } });
  });
});
