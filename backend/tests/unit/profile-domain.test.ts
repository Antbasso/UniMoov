import { describe, expect, it } from 'vitest';
import {
  isDiscoveryMode,
  isPauseActiveOn,
  isPausedOn,
  isRoleModeAllowed,
  nextOnboardingStep,
  parisDate,
  parseRecurrence,
  pauseProblem,
} from '../../src/modules/profile/domain.js';

describe('nextOnboardingStep', () => {
  it('commence par le profil', () => {
    expect(nextOnboardingStep({})).toBe('profile');
  });

  it('reprend à la première étape sans statut, passée ou non', () => {
    expect(nextOnboardingStep({ profile: 'skipped' })).toBe('vehicle');
    expect(nextOnboardingStep({ profile: 'done', vehicle: 'done', calendar: 'skipped' })).toBe('preferences');
  });

  it('renvoie null quand tout est traité', () => {
    expect(
      nextOnboardingStep({ profile: 'done', vehicle: 'skipped', preferences: 'done', calendar: 'skipped' }),
    ).toBeNull();
  });
});

describe('isDiscoveryMode', () => {
  it('reste en découverte sans adresse ou sans campus', () => {
    expect(isDiscoveryMode({ hasHome: false, campusId: 'c' })).toBe(true);
    expect(isDiscoveryMode({ hasHome: true, campusId: null })).toBe(true);
    expect(isDiscoveryMode({ hasHome: true, campusId: 'c' })).toBe(false);
  });
});

describe('isRoleModeAllowed', () => {
  it('sans véhicule : passager uniquement', () => {
    expect(isRoleModeAllowed('always_passenger', false)).toBe(true);
    expect(isRoleModeAllowed('auto', false)).toBe(false);
    expect(isRoleModeAllowed('always_driver', false)).toBe(false);
  });

  it('avec véhicule : tous les modes', () => {
    expect(isRoleModeAllowed('auto', true)).toBe(true);
    expect(isRoleModeAllowed('always_driver', true)).toBe(true);
  });
});

describe('pauses (événements d’agenda)', () => {
  const simple = { startsOn: '2026-11-02', endsOn: '2026-11-08', recurrence: null, repeatUntil: null };
  // Alternance : une semaine (lundi 2 → dimanche 8 novembre) toutes les deux semaines.
  const alternating = { startsOn: '2026-11-02', endsOn: '2026-11-08', recurrence: 'weekly:2', repeatUntil: '2027-06-30' };

  it('une pause simple couvre ses bornes incluses', () => {
    expect(isPauseActiveOn(simple, '2026-11-01')).toBe(false);
    expect(isPauseActiveOn(simple, '2026-11-02')).toBe(true);
    expect(isPauseActiveOn(simple, '2026-11-08')).toBe(true);
    expect(isPauseActiveOn(simple, '2026-11-09')).toBe(false);
  });

  it('toutes les deux semaines', () => {
    expect(isPauseActiveOn(alternating, '2026-11-04')).toBe(true); // semaine 0
    expect(isPauseActiveOn(alternating, '2026-11-11')).toBe(false); // semaine 1
    expect(isPauseActiveOn(alternating, '2026-11-16')).toBe(true); // semaine 2, lundi
    expect(isPauseActiveOn(alternating, '2026-11-22')).toBe(true); // semaine 2, dimanche
    expect(isPauseActiveOn(alternating, '2027-07-05')).toBe(false); // après la fin de la répétition
  });

  it('tous les lundis jusqu’à une date', () => {
    const mondays = { startsOn: '2026-11-02', endsOn: '2026-11-02', recurrence: 'weekly:1', repeatUntil: '2026-12-31' };
    expect(isPauseActiveOn(mondays, '2026-11-09')).toBe(true);
    expect(isPauseActiveOn(mondays, '2026-11-10')).toBe(false);
    expect(isPauseActiveOn(mondays, '2027-01-04')).toBe(false);
  });

  it('certains jours chaque semaine (lundi et mercredi)', () => {
    const days = { startsOn: '2026-11-02', endsOn: '2026-11-02', recurrence: 'days:3,1', repeatUntil: '2026-11-30' };
    expect(isPauseActiveOn(days, '2026-11-04')).toBe(true); // mercredi
    expect(isPauseActiveOn(days, '2026-11-05')).toBe(false); // jeudi
    expect(isPauseActiveOn(days, '2026-11-30')).toBe(true); // lundi, dernier jour
    expect(isPauseActiveOn(days, '2026-10-26')).toBe(false); // avant le début
  });

  it('tous les mois, au même jour, ramené à la fin des mois courts', () => {
    const monthly = { startsOn: '2027-01-31', endsOn: '2027-01-31', recurrence: 'monthly:1', repeatUntil: '2027-06-30' };
    expect(isPauseActiveOn(monthly, '2027-02-28')).toBe(true);
    expect(isPauseActiveOn(monthly, '2027-03-31')).toBe(true);
    expect(isPauseActiveOn(monthly, '2027-03-30')).toBe(false);
    const everyTwo = { startsOn: '2026-11-02', endsOn: '2026-11-06', recurrence: 'monthly:2', repeatUntil: '2027-06-30' };
    expect(isPauseActiveOn(everyTwo, '2027-01-04')).toBe(true);
    expect(isPauseActiveOn(everyTwo, '2026-12-03')).toBe(false);
  });

  it('traverse le changement d’heure sans décalage', () => {
    const overDst = { startsOn: '2027-03-22', endsOn: '2027-03-28', recurrence: 'weekly:2', repeatUntil: '2027-04-30' };
    expect(isPauseActiveOn(overDst, '2027-04-05')).toBe(true); // 2 semaines plus tard
    expect(isPauseActiveOn(overDst, '2027-03-29')).toBe(false);
  });

  it('isPausedOn combine plusieurs pauses', () => {
    expect(isPausedOn([], '2026-11-04')).toBe(false);
    expect(isPausedOn([simple, alternating], '2026-11-11')).toBe(false);
    expect(isPausedOn([simple, alternating], '2026-11-04')).toBe(true);
  });

  it('parseRecurrence lit les trois formes et refuse le reste', () => {
    expect(parseRecurrence('weekly:3')).toEqual({ kind: 'weekly', every: 3 });
    expect(parseRecurrence('monthly:1')).toEqual({ kind: 'monthly', every: 1 });
    expect(parseRecurrence('days:5,1,1')).toEqual({ kind: 'days', weekdays: [1, 5] });
    for (const bad of ['weekly:0', 'weekly:9', 'monthly:7', 'days:', 'days:8', 'yearly:1']) {
      expect(() => parseRecurrence(bad), bad).toThrow(RangeError);
    }
  });

  it('pauseProblem : bornes, répétition et durée', () => {
    expect(pauseProblem(simple)).toBeNull();
    expect(pauseProblem(alternating)).toBeNull();
    expect(pauseProblem({ ...simple, endsOn: '2026-11-01' })).toMatch(/précède/);
    expect(pauseProblem({ ...simple, recurrence: 'weekly:1' })).toMatch(/fin de répétition/);
    expect(pauseProblem({ ...alternating, repeatUntil: '2026-11-05' })).toMatch(/avant la fin/);
    expect(pauseProblem({ ...alternating, repeatUntil: '2027-11-30' })).toMatch(/un an/);
    expect(pauseProblem({ ...alternating, recurrence: 'weekly:1', endsOn: '2026-11-10' })).toMatch(/plus longue/);
    expect(pauseProblem({ ...alternating, recurrence: 'monthly:1', endsOn: '2026-12-15' })).toMatch(/28 jours/);
    expect(pauseProblem({ ...alternating, recurrence: 'yearly:1' })).toMatch(/inconnue/);
  });
});

describe('parisDate', () => {
  it('utilise le fuseau de Paris, pas UTC', () => {
    expect(parisDate(new Date('2026-10-15T22:30:00Z'))).toBe('2026-10-16');
    expect(parisDate(new Date('2026-01-15T22:30:00Z'))).toBe('2026-01-15');
  });
});
