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
    test('lit la récurrence et produit le corps de requête', () {
      final pause = Pause.fromJson({
        'id': 'p',
        'startsOn': '2026-11-02',
        'endsOn': '2027-06-30',
        'recurrence': 'weekly:2',
      });
      expect(pause.everyWeeks, 2);
      expect(Pause.requestBody(DateTime(2026, 1, 5), DateTime(2026, 2, 1), null), {
        'startsOn': '2026-01-05',
        'endsOn': '2026-02-01',
        'recurrence': null,
      });
      expect(
        Pause.requestBody(DateTime(2026, 1, 5), DateTime(2026, 2, 1), 2)['recurrence'],
        'weekly:2',
      );
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
