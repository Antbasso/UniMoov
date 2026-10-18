import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { publicSector } from '../../src/modules/matching/service.js';
import { sectorOf } from '../../src/shared/geo.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/**
 * Critères d'acceptation de M2 sur le jeu de seed : semaine du lundi 19 octobre 2026
 * (heure d'été), horloge au dimanche 18.
 */
let ctx: TestContext;
const WEEK = '2026-W43';
const MONDAY = '2026-10-19';
const FRIDAY = '2026-10-23';
const tokens = new Map<string, Tokens>();

interface Person {
  userId: string;
  firstName: string;
  detourMinutes: number;
  status: string;
}
interface Proposal {
  id: string;
  day: string;
  direction: 'to_campus' | 'from_campus';
  role: 'driver' | 'passenger';
  myStatus: string;
  rideStatus: string;
  detourMinutes: number;
  priceCents: number | null;
  driver: Person | null;
  passengers: Person[];
}

const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;

async function login(firstName: string): Promise<Tokens> {
  const cached = tokens.get(firstName);
  if (cached) return cached;
  const response = await ctx.app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    payload: { universityEmail: user(firstName).email, password: DEMO_PASSWORD },
  });
  expect(response.statusCode).toBe(200);
  const t = response.json<Tokens>();
  tokens.set(firstName, t);
  return t;
}

async function call(firstName: string, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) {
  return ctx.app.inject({
    method,
    url: `/api/v1${url}`,
    headers: bearer(await login(firstName)),
    ...(payload ? { payload } : {}),
  });
}

async function proposals(firstName: string): Promise<Proposal[]> {
  const response = await call(firstName, 'GET', `/proposals?week=${WEEK}`);
  expect(response.statusCode).toBe(200);
  return response.json<{ proposals: Proposal[] }>().proposals;
}

const find = (list: Proposal[], day: string, direction: Proposal['direction']) =>
  list.find((p) => p.day === day && p.direction === direction);

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await runSeed(ctx.database.db, { today: MONDAY });
});
afterAll(async () => {
  await ctx.close();
});

describe('semaine générée sur le jeu de seed', () => {
  it('Hugo (Cran-Gevrier, sans voiture) part et rentre avec Léa chaque jour', async () => {
    const list = await proposals('Hugo');
    expect(list).toHaveLength(10);
    for (const p of list) {
      expect(p.role).toBe('passenger');
      expect(p.driver?.firstName).toBe('Léa');
      expect(p.detourMinutes).toBeLessThanOrEqual(2); // Cran-Gevrier est sur sa route
    }
  });

  it('Léa (mode automatique) conduit le lundi avec trois passagers proches', async () => {
    const monday = find(await proposals('Léa'), MONDAY, 'to_campus')!;
    expect(monday.role).toBe('driver');
    expect(monday.passengers.map((p) => p.firstName).sort()).toEqual(['Chloé', 'Hugo', 'Inès']);
    expect(monday.detourMinutes).toBeLessThanOrEqual(10); // son seuil de détour
    // Prix sur l'accueil : ce qu'elle recevrait de ses trois passagers ; chacun voit sa part.
    const hugo = find(await proposals('Hugo'), MONDAY, 'to_campus')!;
    expect(monday.priceCents).toBeGreaterThan(0);
    expect(hugo.priceCents).toBeGreaterThan(0);
  });

  it('Inès (absente le vendredi) n’a pas de proposition ce jour-là', async () => {
    const list = await proposals('Inès');
    expect(list.filter((p) => p.day === FRIDAY)).toEqual([]);
    expect(list.filter((p) => p.day === MONDAY)).toHaveLength(2);
  });

  it('Théo (cours à 10 h le lundi) n’a pas d’aller ce lundi, faute de voiture à son heure', async () => {
    const list = await proposals('Théo');
    expect(find(list, MONDAY, 'to_campus')).toBeUndefined();
  });

  it('Manon va au campus avec Nathan le lundi, mais rentre trop tôt pour lui', async () => {
    const list = await proposals('Manon');
    expect(find(list, MONDAY, 'to_campus')?.driver?.firstName).toBe('Nathan');
    expect(find(list, MONDAY, 'from_campus')).toBeUndefined();
  });

  it('le vendredi, Léa conduit (marge de places) et Manon trouve une place', async () => {
    const friday = find(await proposals('Léa'), FRIDAY, 'to_campus')!;
    expect(friday.role).toBe('driver');
    expect(friday.passengers.map((p) => p.firstName)).toContain('Manon');
  });

  it('la génération n’est faite qu’une fois : mêmes identifiants au second appel', async () => {
    const first = (await proposals('Hugo')).map((p) => p.id);
    const second = (await proposals('Hugo')).map((p) => p.id);
    expect(second).toEqual(first);
  });

  it('refuse une semaine invalide', async () => {
    expect((await call('Hugo', 'GET', '/proposals?week=2026-W99')).statusCode).toBe(400);
  });
});

describe('confidentialité avant acceptation', () => {
  /** Toutes les positions {lat, lon} d'une réponse, quelle que soit leur profondeur. */
  const positions = (value: unknown): { lat: number; lon: number }[] =>
    value && typeof value === 'object'
      ? [
          ...('lat' in value && 'lon' in value ? [value as { lat: number; lon: number }] : []),
          ...Object.values(value).flatMap(positions),
        ]
      : [];

  it('aucun nom de famille, mail ni adresse d’un autre étudiant', async () => {
    for (const viewer of seedUsers) {
      const body = JSON.stringify((await call(viewer.firstName, 'GET', `/proposals?week=${WEEK}`)).json());
      for (const other of seedUsers.filter((u) => u.id !== viewer.id)) {
        expect(body).not.toContain(other.lastName);
        expect(body).not.toContain(other.homeAddress);
        expect(body).not.toContain(other.email);
      }
    }
  });

  it('les positions renvoyées sont des centres de secteur, jamais un domicile exact', async () => {
    const centers = seedUsers.map((u) => publicSector(sectorOf(u)));
    for (const viewer of seedUsers) {
      const found = positions((await call(viewer.firstName, 'GET', `/proposals?week=${WEEK}`)).json());
      for (const position of found) {
        expect(centers).toContainEqual(position);
        expect(seedUsers.some((u) => u.lat === position.lat && u.lon === position.lon)).toBe(false);
      }
    }
  });

  it('une personne n’expose que les champs publics (secteur au lieu de l’adresse)', async () => {
    const monday = find(await proposals('Léa'), MONDAY, 'to_campus')!;
    for (const person of monday.passengers) {
      expect(Object.keys(person).sort()).toEqual(
        ['detourMinutes', 'firstName', 'photoUrl', 'reliabilityScore', 'sector', 'status', 'userId'].sort(),
      );
    }
  });
});

describe('accepter, refuser, voir d’autres', () => {
  it('confirmation à deux : le trajet est confirmé quand conducteur et passager acceptent', async () => {
    const ride = find(await proposals('Hugo'), MONDAY, 'to_campus')!;
    const byHugo = await call('Hugo', 'POST', `/proposals/${ride.id}/accept`);
    expect(byHugo.json()).toMatchObject({ myStatus: 'accepted', rideStatus: 'proposed' });
    const byLea = await call('Léa', 'POST', `/proposals/${ride.id}/accept`);
    expect(byLea.json()).toMatchObject({ myStatus: 'accepted', rideStatus: 'confirmed' });
  });

  it('un passager refuse : la paire n’est plus reproposée ce jour-là', async () => {
    const ride = find(await proposals('Chloé'), MONDAY, 'from_campus')!;
    expect((await call('Chloé', 'POST', `/proposals/${ride.id}/decline`)).statusCode).toBe(204);
    expect(find(await proposals('Chloé'), MONDAY, 'from_campus')).toBeUndefined();
    const lea = find(await proposals('Léa'), MONDAY, 'from_campus')!;
    expect(lea.passengers.map((p) => p.firstName)).not.toContain('Chloé');
    // Répondre deux fois est refusé.
    const again = await call('Chloé', 'POST', `/proposals/${ride.id}/decline`);
    expect(again.statusCode).toBe(409);
    expect(again.json()).toMatchObject({ error: { code: 'already_answered' } });
  });

  it('voir d’autres puis choisir une autre voiture', async () => {
    const ride = find(await proposals('Manon'), FRIDAY, 'to_campus')!;
    const alternatives = await call('Manon', 'GET', `/proposals/${ride.id}/alternatives`);
    expect(alternatives.statusCode).toBe(200);
    const rides = alternatives.json<{ rides: { rideId: string; driver: Person }[] }>().rides;
    expect(rides.map((r) => r.driver.firstName)).toContain('Nathan');
    const nathan = rides.find((r) => r.driver.firstName === 'Nathan')!;
    const accepted = await call('Manon', 'POST', `/proposals/${nathan.rideId}/accept`);
    expect(accepted.statusCode).toBe(200);
    // Voiture choisie par Manon : Nathan doit d'abord accepter sa demande.
    expect(accepted.json()).toMatchObject({ myStatus: 'requested', driver: { firstName: 'Nathan' } });
    // L'ancienne proposition avec Léa a disparu de sa semaine.
    const friday = (await proposals('Manon')).filter((p) => p.day === FRIDAY && p.direction === 'to_campus');
    expect(friday.map((p) => p.driver?.firstName)).toEqual(['Nathan']);
  });

  it('un étranger au trajet ne peut ni le refuser, ni voir ses alternatives', async () => {
    const ride = find(await proposals('Hugo'), FRIDAY, 'to_campus')!;
    expect((await call('Lucas', 'POST', `/proposals/${ride.id}/decline`)).statusCode).toBe(404);
    expect((await call('Lucas', 'GET', `/proposals/${ride.id}/alternatives`)).statusCode).toBe(404);
    // Accepter sans y avoir droit : Lucas habite trop loin pour le détour de Léa.
    const forced = await call('Lucas', 'POST', `/proposals/${ride.id}/accept`);
    expect(forced.statusCode).toBe(409);
    expect(forced.json()).toMatchObject({ error: { code: 'ride_unavailable' } });
    expect((await call('Lucas', 'POST', '/proposals/00000000-0000-4000-8000-000000000999/accept')).statusCode).toBe(404);
  });
});

describe('relance sur changement d’horaire', () => {
  it('Hugo commence à 10 h le jeudi : sa proposition de l’aller est recalculée', async () => {
    const thursday = '2026-10-22';
    // Conducteur du jeudi : celui qui a le moins conduit récemment (alternance du mode automatique).
    const driver = find(await proposals('Hugo'), thursday, 'to_campus')?.driver?.firstName;
    expect(driver).toBeDefined();
    const days = user('Hugo').week;
    const response = await call('Hugo', 'PUT', '/schedule/manual', {
      days: Object.entries(days).map(([weekday, [startTime, endTime]]) => ({
        weekday: Number(weekday),
        startTime: Number(weekday) === 4 ? '10:00' : startTime,
        endTime,
      })),
    });
    expect(response.statusCode).toBe(200);
    // Tous les jeudis de l'horizon (28 jours) changent ; seul celui de la semaine est généré.
    expect(response.json<{ changedDays: string[] }>().changedDays).toEqual([
      thursday,
      '2026-10-29',
      '2026-11-05',
      '2026-11-12',
    ]);
    // Plus de voiture à 10 h : plus de proposition d'aller ; le retour reste.
    const after = await proposals('Hugo');
    expect(find(after, thursday, 'to_campus')).toBeUndefined();
    expect(find(after, thursday, 'from_campus')?.driver?.firstName).toBeDefined();
    const theirs = find(await proposals(driver!), thursday, 'to_campus')!;
    expect(theirs.passengers.map((p) => p.firstName)).not.toContain('Hugo');
  });

  it('un trajet confirmé n’est pas recalculé par une relance', async () => {
    const confirmed = find(await proposals('Hugo'), MONDAY, 'to_campus')!;
    expect(confirmed.rideStatus).toBe('confirmed');
    // Chloé change son lundi : le lundi est relancé, le trajet confirmé reste.
    await call('Chloé', 'PUT', '/schedule/manual', {
      days: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, startTime: weekday === 1 ? '13:00' : '08:15', endTime: '16:30' })),
    });
    expect(find(await proposals('Hugo'), MONDAY, 'to_campus')!.id).toBe(confirmed.id);
  });

  it('une pause retire l’étudiant des propositions des jours concernés', async () => {
    expect(find(await proposals('Inès'), '2026-10-20', 'to_campus')).toBeDefined();
    const pause = await call('Inès', 'POST', '/me/pauses', {
      startsOn: '2026-10-20',
      endsOn: '2026-10-20',
      recurrence: null,
    });
    expect(pause.statusCode).toBe(201);
    expect((await proposals('Inès')).filter((p) => p.day === '2026-10-20')).toEqual([]);
  });
});

describe('recherche manuelle', () => {
  it('trouve des voitures compatibles sans exposer de donnée sensible', async () => {
    const response = await call('Théo', 'GET', `/search/rides?day=${MONDAY}&direction=to_campus&time=08:00`);
    expect(response.statusCode).toBe(200);
    const body = JSON.stringify(response.json());
    for (const other of seedUsers) {
      expect(body).not.toContain(other.lastName);
      expect(body).not.toContain(other.homeAddress);
    }
  });

  it('sans cours ce jour-là, on peut rejoindre une voiture trouvée par la recherche', async () => {
    // Inès n'a pas de cours le vendredi : elle cherche un aller pour 8 h.
    const search = await call('Inès', 'GET', `/search/rides?day=${FRIDAY}&direction=to_campus&time=08:00`);
    const rides = search.json<{ rides: { rideId: string; driver: Person; priceCents: number | null }[] }>().rides;
    expect(rides.length).toBeGreaterThan(0);
    // Prix affiché au choix de la voiture : ce qu'elle paierait, son détour compris.
    expect(rides[0]!.priceCents).toBeGreaterThan(0);
    const rideId = rides[0]!.rideId;
    const joined = await call('Inès', 'POST', `/proposals/${rideId}/accept`);
    expect(joined.statusCode).toBe(200);
    expect(joined.json()).toMatchObject({ role: 'passenger', myStatus: 'requested' });
    const driverName = rides[0]!.driver.firstName;
    expect(ctx.notifier.sent).toContainEqual(expect.objectContaining({ event: { type: 'ride_requested', rideId } }));

    // Tant que le conducteur n'a pas répondu : ni le trajet, ni son nom, ni son adresse.
    expect((await call('Inès', 'GET', `/rides/${rideId}`)).statusCode).toBe(403);
    // Lui voit la demande, au prénom seulement.
    const driverView = (await proposals(driverName)).find((p) => p.id === rideId)!;
    expect(driverView.passengers).toContainEqual(expect.objectContaining({ firstName: 'Inès', status: 'requested' }));
    expect(JSON.stringify(driverView)).not.toContain(user('Inès').lastName);
    // Un autre que le conducteur ne peut pas répondre.
    expect((await call('Inès', 'POST', `/rides/${rideId}/requests/${user('Inès').id}/approve`)).statusCode).toBe(403);

    const approved = await call(driverName, 'POST', `/rides/${rideId}/requests/${user('Inès').id}/approve`);
    expect(approved.statusCode).toBe(200);
    expect(ctx.notifier.sent).toContainEqual(expect.objectContaining({ event: { type: 'request_answered', rideId, approved: true } }));
    expect((await proposals('Inès')).find((p) => p.id === rideId)).toMatchObject({ myStatus: 'accepted', rideStatus: 'confirmed' });
    // Accepter le passager suffit : le trajet est confirmé, le conducteur accepté d'office.
    expect(approved.json()).toMatchObject({ myStatus: 'accepted', rideStatus: 'confirmed' });
    expect((await call('Inès', 'GET', `/rides/${rideId}`)).statusCode).toBe(200);
    // Déjà traitée : plus rien à approuver.
    expect((await call(driverName, 'POST', `/rides/${rideId}/requests/${user('Inès').id}/reject`)).statusCode).toBe(404);
  });

  it('demande refusée : la paire n’est plus reproposée, une autre voiture est cherchée', async () => {
    const ride = find(await proposals('Manon'), FRIDAY, 'to_campus')!;
    expect(ride.myStatus).toBe('requested');
    const nathan = ride.driver!.firstName;
    const rejected = await call(nathan, 'POST', `/rides/${ride.id}/requests/${user('Manon').id}/reject`);
    expect(rejected.statusCode).toBe(200);
    expect(ctx.notifier.sent).toContainEqual(
      expect.objectContaining({ userIds: [user('Manon').id], event: { type: 'request_answered', rideId: ride.id, approved: false } }),
    );
    // Ce trajet ne figure plus parmi ses propositions actives.
    const after = (await proposals('Manon')).find((p) => p.id === ride.id);
    expect(after === undefined || after.myStatus === 'declined').toBe(true);
  });

  it('refuse une date passée', async () => {
    expect((await call('Théo', 'GET', '/search/rides?day=2026-10-01&direction=to_campus')).statusCode).toBe(400);
  });

  it('applique le quota quotidien (20 par défaut)', async () => {
    let last = 200;
    for (let i = 0; i < 25 && last === 200; i++) {
      last = (await call('Lucas', 'GET', `/search/rides?day=${MONDAY}&direction=to_campus`)).statusCode;
    }
    expect(last).toBe(429);
    const blocked = await call('Lucas', 'GET', `/search/rides?day=${MONDAY}&direction=to_campus`);
    expect(blocked.json()).toMatchObject({ error: { code: 'search_quota_exceeded' } });
  });
});
