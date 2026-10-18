import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../src/db/seed.js';
import { DEMO_PASSWORD, seedUsers } from '../../src/db/seed-data.js';
import { publicSector } from '../../src/modules/matching/service.js';
import { distanceMeters, sectorOf } from '../../src/shared/geo.js';
import { bearer, setupTestContext, type TestContext, type Tokens } from './helpers.js';

/**
 * Critères d'acceptation de M3 sur le jeu de seed : la carte montre le conducteur et les
 * passagers acceptés avec leur adresse ou point de rendez-vous ; un non-participant reçoit 403.
 */
let ctx: TestContext;
const WEEK = '2026-W43';
const MONDAY = '2026-10-19';
const TUESDAY = '2026-10-20';
const tokens = new Map<string, Tokens>();

interface Stop {
  order: number;
  kind: 'driver' | 'passenger' | 'campus';
  userId: string | null;
  firstName: string | null;
  lastName: string | null;
  label: string;
  lat: number;
  lon: number;
  eta: string | null;
  isMeetingPoint: boolean;
}
interface Ride {
  id: string;
  status: string;
  role: string;
  time: string;
  distanceM: number;
  durationS: number;
  routeEstimated: boolean;
  route: [number, number][];
  stops: Stop[];
  price: {
    totalCostCents: number;
    persons: number;
    shareCents: number;
    commissionCents: number;
    youPayCents: number | null;
    youReceiveCents: number | null;
  } | null;
}
interface Proposal {
  id: string;
  day: string;
  direction: 'to_campus' | 'from_campus';
  role: string;
  passengers: { firstName: string; status: string }[];
}

const user = (firstName: string) => seedUsers.find((u) => u.firstName === firstName)!;

async function call(firstName: string, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) {
  let t = tokens.get(firstName);
  if (!t) {
    const login = await ctx.app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { universityEmail: user(firstName).email, password: DEMO_PASSWORD },
    });
    t = login.json<Tokens>();
    tokens.set(firstName, t);
  }
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: bearer(t), ...(payload ? { payload } : {}) });
}

async function proposal(firstName: string, day: string, direction: Proposal['direction']): Promise<Proposal> {
  const response = await call(firstName, 'GET', `/proposals?week=${WEEK}`);
  return response.json<{ proposals: Proposal[] }>().proposals.find((p) => p.day === day && p.direction === direction)!;
}

const ride = async (firstName: string, id: string) => {
  const response = await call(firstName, 'GET', `/rides/${id}`);
  expect(response.statusCode).toBe(200);
  return response.json<Ride>();
};

let mondayId: string;

beforeAll(async () => {
  ctx = await setupTestContext(new Date('2026-10-18T10:00:00Z'));
  await runSeed(ctx.database.db, { today: MONDAY });
  // Lundi aller : Léa conduit Hugo, Chloé et Inès (voir proposals.test.ts).
  mondayId = (await proposal('Léa', MONDAY, 'to_campus')).id;
});
afterAll(async () => {
  await ctx.close();
});

describe('carte d’un trajet confirmé', () => {
  it('aperçu avant confirmation : tracé sans les abords des domiciles des autres, mon point exact', async () => {
    const response = await call('Hugo', 'GET', `/rides/${mondayId}/preview`);
    expect(response.statusCode).toBe(200);
    const preview = response.json<{ route: [number, number][]; campus: { lat: number }; me: { lat: number; lon: number } }>();
    expect(preview.me).toEqual({ lat: user('Hugo').lat, lon: user('Hugo').lon });
    expect(preview.route.length).toBeGreaterThan(0);
    for (const [lat, lon] of preview.route) {
      for (const other of ['Léa', 'Chloé', 'Inès']) {
        expect(distanceMeters({ lat, lon }, user(other))).toBeGreaterThan(500);
      }
    }
    expect(JSON.stringify(preview)).not.toContain(user('Léa').homeAddress);
    // Un tiers n'y a pas accès.
    expect((await call('Nathan', 'GET', `/rides/${mondayId}/preview`)).statusCode).toBe(403);
    // Pas encore de trajet terminé : historique vide.
    expect((await call('Hugo', 'GET', '/rides/history')).json()).toEqual({ rides: [] });
  });

  it('avant la confirmation à deux, même les participants n’y ont pas accès', async () => {
    expect((await call('Léa', 'GET', `/rides/${mondayId}`)).statusCode).toBe(403);
    expect((await call('Léa', 'POST', `/proposals/${mondayId}/accept`)).statusCode).toBe(200);
    // Le conducteur a accepté, aucun passager encore : pas confirmé.
    const pending = await call('Léa', 'GET', `/rides/${mondayId}`);
    expect(pending.statusCode).toBe(409);
    expect(pending.json<{ error: { code: string } }>().error.code).toBe('ride_not_confirmed');
  });

  it('le conducteur voit le tracé, son départ, les passagers acceptés et le campus, dans l’ordre', async () => {
    expect((await call('Hugo', 'POST', `/proposals/${mondayId}/accept`)).statusCode).toBe(200);
    const view = await ride('Léa', mondayId);
    expect(view.status).toBe('confirmed');
    expect(view.role).toBe('driver');
    // Chloé et Inès n'ont pas encore accepté : absentes de la carte.
    expect(view.stops.map((s) => [s.kind, s.firstName])).toEqual([
      ['driver', 'Léa'],
      ['passenger', 'Hugo'],
      ['campus', null],
    ]);
    const hugo = view.stops[1]!;
    expect(hugo).toMatchObject({ lastName: 'Bernard', label: user('Hugo').homeAddress, isMeetingPoint: false });
    expect([hugo.lat, hugo.lon]).toEqual([user('Hugo').lat, user('Hugo').lon]);

    // Sans fournisseur dans les tests : tracé estimé passant par les arrêts.
    expect(view.routeEstimated).toBe(true);
    expect(view.route[0]).toEqual([user('Léa').lat, user('Léa').lon]);
    expect(view.route).toHaveLength(3);
    expect(view.distanceM).toBeGreaterThan(5000);

    // Heures de passage croissantes, arrivée au campus à l'heure cible.
    const etas = view.stops.map((s) => new Date(s.eta!).getTime());
    expect(etas).toEqual([...etas].sort((a, b) => a - b));
    expect(view.stops.at(-1)!.eta).toBe(view.time);
    expect(etas.at(-1)! - etas[0]!).toBe(view.durationS * 1000);
  });

  it('prix estimé : coût partagé à deux, commission pour le passager seulement', async () => {
    const driverView = await ride('Léa', mondayId);
    const cost = Math.round((5.8 * driverView.distanceM * 180) / 100_000);
    expect(driverView.price).toMatchObject({ totalCostCents: cost, persons: 2, youPayCents: null });
    expect(driverView.price!.youReceiveCents).toBe(driverView.price!.shareCents);

    const passengerView = await ride('Hugo', mondayId);
    expect(passengerView.price!.youPayCents).toBe(passengerView.price!.shareCents + 20);
    expect(passengerView.price!.youReceiveCents).toBeNull();
    const response = await call('Hugo', 'GET', `/rides/${mondayId}/price`);
    expect(response.json<{ price: unknown }>().price).toEqual(passengerView.price);
  });

  it('le passager voit le nom du conducteur et son départ ; entre passagers, prénom seulement', async () => {
    expect((await call('Inès', 'POST', `/proposals/${mondayId}/accept`)).statusCode).toBe(200);
    const view = await ride('Hugo', mondayId);
    const byName = new Map(view.stops.map((s) => [s.firstName, s]));
    // Le domicile du conducteur ne sert pas au passager : son départ reste approximatif.
    expect(byName.get('Léa')).toMatchObject({ lastName: 'Martin', label: '', approximate: true });
    expect({ lat: byName.get('Léa')!.lat, lon: byName.get('Léa')!.lon }).toEqual(publicSector(sectorOf(user('Léa'))));
    expect(JSON.stringify(view)).not.toContain(user('Léa').homeAddress);
    expect(byName.get('Hugo')!.lastName).toBe('Bernard');
    // Entre passagers, pas d'acceptation mutuelle : secteur seulement, sans adresse (cahier §4, §14).
    const ines = byName.get('Inès')!;
    expect(ines).toMatchObject({ lastName: null, label: '' });
    expect({ lat: ines.lat, lon: ines.lon }).toEqual(publicSector(sectorOf(user('Inès'))));
    expect(JSON.stringify(view)).not.toContain(user('Inès').homeAddress);
    for (const [lat, lon] of view.route) {
      expect(distanceMeters({ lat, lon }, user('Inès'))).toBeGreaterThan(500);
      expect(distanceMeters({ lat, lon }, user('Léa'))).toBeGreaterThan(500);
    }
    // Le conducteur, lui, voit l'adresse exacte de chacun.
    const driverView = await ride('Léa', mondayId);
    expect(driverView.stops.find((s) => s.firstName === 'Inès')).toMatchObject({
      label: user('Inès').homeAddress,
      lat: user('Inès').lat,
      lon: user('Inès').lon,
    });
    // Le plan a été recalculé avec Inès : trois personnes se partagent le coût.
    expect(view.stops.map((s) => s.firstName)).toEqual(['Léa', 'Hugo', 'Inès', null]);
    expect(view.price!.persons).toBe(3);
  });

  it('un non-participant ou un participant qui n’a pas accepté reçoit 403', async () => {
    for (const name of ['Nathan', 'Chloé']) {
      const response = await call(name, 'GET', `/rides/${mondayId}`);
      expect(response.statusCode).toBe(403);
      expect(response.json<{ error: { code: string } }>().error.code).toBe('forbidden');
      expect((await call(name, 'GET', `/rides/${mondayId}/price`)).statusCode).toBe(403);
    }
    expect((await call('Nathan', 'GET', '/rides/00000000-0000-4000-8000-999999999999')).statusCode).toBe(404);
    const anonymous = await ctx.app.inject({ method: 'GET', url: `/api/v1/rides/${mondayId}` });
    expect(anonymous.statusCode).toBe(401);
  });

  it('un trajet où seul le conducteur a accepté reste fermé', async () => {
    const tuesday = await proposal('Léa', TUESDAY, 'to_campus');
    expect((await call('Léa', 'POST', `/proposals/${tuesday.id}/accept`)).statusCode).toBe(200);
    expect((await call('Léa', 'GET', `/rides/${tuesday.id}`)).statusCode).toBe(409);
  });
});

describe('changement d’adresse après confirmation', () => {
  it('le plan est recalculé avec la nouvelle adresse du passager', async () => {
    const before = await ride('Léa', mondayId);
    // Hugo déménage à Annecy (adresse connue du géocodeur factice).
    const moved = await call('Hugo', 'PUT', '/me/address', { address: '12 rue de la Paix, Annecy' });
    expect(moved.statusCode).toBe(200);
    const after = await ride('Léa', mondayId);
    const hugo = after.stops.find((s) => s.firstName === 'Hugo')!;
    expect([hugo.lat, hugo.lon]).toEqual([45.9003, 6.1251]);
    expect(after.route).toContainEqual([45.9003, 6.1251]);
    expect(after.distanceM).not.toBe(before.distanceM);
    // Retour à l'adresse du seed pour la suite.
    await ctx.database.pool.query(
      `UPDATE users SET home_address = $1, home_location = ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography WHERE id = $4`,
      [user('Hugo').homeAddress, user('Hugo').lat, user('Hugo').lon, user('Hugo').id],
    );
    await ctx.database.pool.query(`UPDATE rides SET planned_at = NULL WHERE id = $1`, [mondayId]);
  });
});

describe('point de rendez-vous', () => {
  const stop = { label: 'Arrêt Mairie de Cran-Gevrier', lat: 45.9035, lon: 6.1065 };

  it('remplace l’adresse du passager auprès du conducteur et recalcule le plan', async () => {
    const response = await call('Hugo', 'PUT', `/rides/${mondayId}/me/pickup`, { useMeetingPoint: true, ...stop });
    expect(response.statusCode).toBe(204);
    const view = await ride('Léa', mondayId);
    const hugo = view.stops.find((s) => s.firstName === 'Hugo')!;
    expect(hugo).toMatchObject({ label: stop.label, lat: stop.lat, lon: stop.lon, isMeetingPoint: true });
    expect(view.route).toContainEqual([stop.lat, stop.lon]);
    expect(JSON.stringify(view)).not.toContain(user('Hugo').homeAddress);
  });

  it('refuse un point trop loin du domicile, ou incomplet', async () => {
    const far = await call('Hugo', 'PUT', `/rides/${mondayId}/me/pickup`, { useMeetingPoint: true, label: 'Campus', lat: 45.9195, lon: 6.158 });
    expect(far.statusCode).toBe(422);
    expect(far.json<{ error: { code: string } }>().error.code).toBe('meeting_point_too_far');
    expect((await call('Hugo', 'PUT', `/rides/${mondayId}/me/pickup`, { useMeetingPoint: true })).statusCode).toBe(400);
  });

  it('réservé aux passagers acceptés de ce trajet', async () => {
    for (const name of ['Léa', 'Nathan', 'Chloé']) {
      expect((await call(name, 'PUT', `/rides/${mondayId}/me/pickup`, { useMeetingPoint: false })).statusCode).toBe(403);
    }
  });

  it('revenir à son adresse', async () => {
    expect((await call('Hugo', 'PUT', `/rides/${mondayId}/me/pickup`, { useMeetingPoint: false })).statusCode).toBe(204);
    const hugo = (await ride('Léa', mondayId)).stops.find((s) => s.firstName === 'Hugo')!;
    expect(hugo).toMatchObject({ label: user('Hugo').homeAddress, isMeetingPoint: false });
  });
});

describe('suggestions de passagers pour le conducteur', () => {
  // Lundi retour : Nathan (Sévrier, 18 h) n'a personne ; Théo (Pringy, fin à 18 h) n'a pas de trajet.
  let nathanId: string;
  beforeAll(async () => {
    nathanId = (await proposal('Nathan', MONDAY, 'from_campus')).id;
  });

  it('réservées au conducteur, après avoir accepté son trajet', async () => {
    expect((await call('Hugo', 'GET', `/rides/${mondayId}/suggestions`)).statusCode).toBe(403);
    const early = await call('Nathan', 'GET', `/rides/${nathanId}/suggestions`);
    expect(early.statusCode).toBe(409);
    expect(early.json<{ error: { code: string } }>().error.code).toBe('accept_first');
  });

  it('inclut les passagers écartés car hors détour, avec la simulation du prix', async () => {
    expect((await call('Nathan', 'POST', `/proposals/${nathanId}/accept`)).statusCode).toBe(200);
    const response = await call('Nathan', 'GET', `/rides/${nathanId}/suggestions`);
    expect(response.statusCode).toBe(200);
    const body = response.json<{
      seatsLeft: number;
      current: { persons: number; shareCents: number };
      suggestions: {
        person: { userId: string; firstName: string; sector: { lat: number; lon: number }; detourMinutes: number };
        withinDetourLimit: boolean;
        shareCents: number;
        passengerPaysCents: number;
      }[];
    }>();
    expect(body.seatsLeft).toBe(4);
    expect(body.current.persons).toBe(1);
    const theo = body.suggestions.find((s) => s.person.firstName === 'Théo')!;
    expect(theo.withinDetourLimit).toBe(false);
    expect(theo.person.detourMinutes).toBeGreaterThan(12);
    expect(theo.passengerPaysCents).toBe(theo.shareCents + 20);
    // Avant acceptation : secteur seulement, jamais le domicile.
    expect(theo.person.sector).toEqual(publicSector(sectorOf(user('Théo'))));
    expect(JSON.stringify(body)).not.toMatch(/Simon|Pringy|"lastName"/);
    // Personne déjà dans un trajet ce jour-là dans ce sens.
    expect(body.suggestions.map((s) => s.person.firstName)).not.toContain('Inès');
  });

  it('inviter : le passager reçoit une proposition à accepter', async () => {
    const theoId = user('Théo').id;
    const invited = await call('Nathan', 'POST', `/rides/${nathanId}/suggestions/${theoId}/invite`);
    expect(invited.statusCode).toBe(200);
    expect(invited.json<Proposal>().passengers).toEqual([expect.objectContaining({ firstName: 'Théo', status: 'proposed' })]);
    const theo = await proposal('Théo', MONDAY, 'from_campus');
    expect(theo.id).toBe(nathanId);
    expect(theo.role).toBe('passenger');
    // Déjà proposé : plus dans les suggestions.
    const again = await call('Nathan', 'POST', `/rides/${nathanId}/suggestions/${theoId}/invite`);
    expect(again.statusCode).toBe(409);
  });
});
