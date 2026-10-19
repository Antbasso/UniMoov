import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/auth/domain/validators.dart';
import 'package:unimoov/features/profile/domain/me.dart';
import 'package:unimoov/features/profile/domain/vehicle_input.dart';

void main() {
  group('Me.fromJson', () {
    final json = {
      'id': '1',
      'universityEmail': 'lea@etu.univ-smb.fr',
      'firstName': 'Léa',
      'lastName': 'Martin',
      'photoUrl': null,
      'campusId': 'c',
      'home': {'address': '12 Rue de la Paix', 'lat': 45.9, 'lon': 6, 'sector': '1:2'},
      'roleMode': 'always_driver',
      'defaultNavApp': null,
      'reliabilityScore': 0.8,
      'vehicle': {'consumptionLPer100km': 5.8, 'defaultSeats': 3, 'maxDetourMinutes': 10},
      'onboarding': {
        'steps': {'profile': 'done', 'vehicle': 'skipped'},
        'nextStep': 'preferences',
        'completed': false,
      },
      'discoveryMode': false,
      'pausedToday': true,
    };

    test('lit le profil complet', () {
      final me = Me.fromJson(json);
      expect(me.roleMode, RoleMode.alwaysDriver);
      expect(me.home!.lon, 6.0);
      expect(me.vehicle!.defaultSeats, 3);
      expect(me.steps, {
        OnboardingStep.profile: StepStatus.done,
        OnboardingStep.vehicle: StepStatus.skipped,
      });
      expect(me.nextStep, OnboardingStep.preferences);
      expect(me.pausedToday, isTrue);
    });

    test('gère l’absence d’adresse, de véhicule et d’étape suivante', () {
      final me = Me.fromJson({
        ...json,
        'home': null,
        'vehicle': null,
        'onboarding': {'steps': <String, dynamic>{}, 'nextStep': null, 'completed': true},
      });
      expect(me.home, isNull);
      expect(me.vehicle, isNull);
      expect(me.nextStep, isNull);
      expect(me.onboardingCompleted, isTrue);
    });

    test('un rôle inconnu retombe sur passager', () {
      expect(RoleMode.fromWire('pilote'), RoleMode.alwaysPassenger);
    });
  });

  group('Pause', () {
    test('lit les trois formes de répétition et produit le corps de requête', () {
      final pause = Pause.fromJson({
        'id': 'p',
        'startsOn': '2026-11-02',
        'endsOn': '2026-11-08',
        'recurrence': 'weekly:2',
        'repeatUntil': '2027-06-30',
      });
      expect((pause.repeat! as RepeatWeekly).every, 2);
      expect(pause.repeatUntil, DateTime(2027, 6, 30));
      expect((PauseRepeat.fromWire('days:3,1')! as RepeatDays).weekdays, {1, 3});
      expect((PauseRepeat.fromWire('monthly:1')! as RepeatMonthly).every, 1);
      expect(PauseRepeat.fromWire(null), isNull);
      expect(PauseDraft(startsOn: DateTime(2026, 1, 5), endsOn: DateTime(2026, 2, 1)).toJson(), {
        'startsOn': '2026-01-05',
        'endsOn': '2026-02-01',
        'recurrence': null,
        'repeatUntil': null,
      });
      expect(
        PauseDraft(
          startsOn: DateTime(2026, 1, 5),
          endsOn: DateTime(2026, 1, 5),
          repeat: const RepeatDays({5, 1}),
          repeatUntil: DateTime(2026, 3, 1),
        ).toJson(),
        containsPair('recurrence', 'days:1,5'),
      );
    });

    test('la première pause doit tenir dans sa période', () {
      final first = DateTime(2026, 11, 2);
      expect(
        PauseDraft(
          startsOn: first,
          endsOn: DateTime(2026, 11, 8),
          repeat: const RepeatWeekly(1),
        ).fitsPeriod,
        isTrue,
      );
      expect(
        PauseDraft(
          startsOn: first,
          endsOn: DateTime(2026, 11, 9),
          repeat: const RepeatWeekly(1),
        ).fitsPeriod,
        isFalse,
      );
      expect(
        PauseDraft(
          startsOn: first,
          endsOn: DateTime(2026, 12, 2),
          repeat: const RepeatMonthly(1),
        ).fitsPeriod,
        isFalse,
      );
    });

    test('pauseCovers suit les mêmes règles que le serveur', () {
      bool on(PauseRepeat? repeat, DateTime day, {DateTime? end}) => pauseCovers(
        startsOn: DateTime(2026, 11, 2),
        endsOn: end ?? DateTime(2026, 11, 2),
        repeat: repeat,
        repeatUntil: repeat == null ? null : DateTime(2027, 6, 30),
        day: day,
      );
      expect(on(null, DateTime(2026, 11, 2)), isTrue);
      expect(on(null, DateTime(2026, 11, 3)), isFalse);
      expect(on(const RepeatWeekly(1), DateTime(2026, 11, 9)), isTrue); // tous les lundis
      expect(on(const RepeatWeekly(2), DateTime(2026, 11, 9)), isFalse);
      expect(on(const RepeatWeekly(2), DateTime(2026, 11, 22), end: DateTime(2026, 11, 8)), isTrue);
      expect(on(const RepeatDays({3}), DateTime(2026, 11, 4)), isTrue); // mercredi
      expect(on(const RepeatMonthly(1), DateTime(2026, 12, 2)), isTrue);
      expect(on(const RepeatMonthly(1), DateTime(2027, 7, 2)), isFalse); // après la fin
    });
  });

  group('VehicleInput', () {
    test('accepte la virgule décimale et arrondit au dixième', () {
      expect(VehicleInput.consumption('5,84'), 5.8);
      expect(VehicleInput.consumption(' 6 '), 6.0);
    });

    test('refuse hors bornes ou non numérique', () {
      expect(VehicleInput.consumption('1,5'), isNull);
      expect(VehicleInput.consumption('abc'), isNull);
      expect(VehicleInput.seats('0'), isNull);
      expect(VehicleInput.seats('9'), isNull);
      expect(VehicleInput.seats('4'), 4);
      expect(VehicleInput.detour('61'), isNull);
      expect(VehicleInput.detour('0'), 0);
    });

    test('affiche la consommation à la française', () {
      expect(VehicleInput.formatConsumption(5.8), '5,8');
    });
  });

  group('AuthValidators', () {
    test('mail, code, mot de passe, nom', () {
      expect(AuthValidators.isEmail(' lea@etu.univ-smb.fr '), isTrue);
      expect(AuthValidators.isEmail('lea@'), isFalse);
      expect(AuthValidators.isCode('012345'), isTrue);
      expect(AuthValidators.isCode('12345'), isFalse);
      expect(AuthValidators.isCode('12a456'), isFalse);
      expect(AuthValidators.isPassword('1234567'), isFalse);
      expect(AuthValidators.isPassword('12345678'), isTrue);
      expect(AuthValidators.isName('  '), isFalse);
    });
  });
}
