import { describe, expect, it } from 'vitest';
import {
  isDiscoveryMode,
  isPauseActiveOn,
  isPausedOn,
  isRoleModeAllowed,
  nextOnboardingStep,
  parisDate,
  parseRecurrence,
  pauseLengthDays,
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

describe('pauses', () => {
  const simple = { startsOn: '2026-11-02', endsOn: '2026-11-08', recurrence: null };
  // Alternance : 2 novembre 2026 est un lundi.
  const alternating = { startsOn: '2026-11-02', endsOn: '2027-06-30', recurrence: 'weekly:2' as const };

  it('une pause simple couvre ses bornes incluses', () => {
    expect(isPauseActiveOn(simple, '2026-11-01')).toBe(false);
    expect(isPauseActiveOn(simple, '2026-11-02')).toBe(true);
    expect(isPauseActiveOn(simple, '2026-11-08')).toBe(true);
    expect(isPauseActiveOn(simple, '2026-11-09')).toBe(false);
  });

  it('une semaine sur deux', () => {
    expect(isPauseActiveOn(alternating, '2026-11-04')).toBe(true); // semaine 0
    expect(isPauseActiveOn(alternating, '2026-11-11')).toBe(false); // semaine 1
    expect(isPauseActiveOn(alternating, '2026-11-16')).toBe(true); // semaine 2, lundi
    expect(isPauseActiveOn(alternating, '2026-11-22')).toBe(true); // semaine 2, dimanche
    expect(isPauseActiveOn(alternating, '2027-07-05')).toBe(false); // après la fin
  });

  it('une récurrence qui démarre un mercredi suit les semaines civiles', () => {
    const fromWednesday = { startsOn: '2026-11-04', endsOn: '2026-12-31', recurrence: 'weekly:2' as const };
    expect(isPauseActiveOn(fromWednesday, '2026-11-02')).toBe(false); // avant le début
    expect(isPauseActiveOn(fromWednesday, '2026-11-08')).toBe(true);
    expect(isPauseActiveOn(fromWednesday, '2026-11-09')).toBe(false);
  });

  it('traverse le changement d’heure sans décalage', () => {
    const overDst = { startsOn: '2027-03-22', endsOn: '2027-04-30', recurrence: 'weekly:2' as const };
    expect(isPauseActiveOn(overDst, '2027-04-05')).toBe(true); // 2 semaines plus tard
    expect(isPauseActiveOn(overDst, '2027-03-29')).toBe(false);
  });

  it('isPausedOn combine plusieurs pauses', () => {
    expect(isPausedOn([], '2026-11-04')).toBe(false);
    expect(isPausedOn([simple, alternating], '2026-11-11')).toBe(false);
    expect(isPausedOn([simple, alternating], '2026-11-04')).toBe(true);
  });

  it('parseRecurrence refuse un format inconnu', () => {
    expect(parseRecurrence(null)).toBeNull();
    expect(parseRecurrence('weekly:3')).toBe(3);
    expect(() => parseRecurrence('monthly:1')).toThrow(RangeError);
    expect(() => parseRecurrence('weekly:1')).toThrow(RangeError);
  });

  it('pauseLengthDays compte les bornes', () => {
    expect(pauseLengthDays(simple)).toBe(7);
  });
});

describe('parisDate', () => {
  it('utilise le fuseau de Paris, pas UTC', () => {
    expect(parisDate(new Date('2026-10-15T22:30:00Z'))).toBe('2026-10-16');
    expect(parisDate(new Date('2026-01-15T22:30:00Z'))).toBe('2026-01-15');
  });
});
