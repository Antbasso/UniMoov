/// Profil privé renvoyé par `GET /me` (docs/api.md, « Profil »).
enum RoleMode {
  auto('auto'),
  alwaysDriver('always_driver'),
  alwaysPassenger('always_passenger');

  const RoleMode(this.wire);
  final String wire;

  static RoleMode fromWire(String value) =>
      values.firstWhere((m) => m.wire == value, orElse: () => alwaysPassenger);

  /// Sans véhicule : passager uniquement (cahier §2).
  bool allowedWithoutVehicle() => this == alwaysPassenger;
}

enum OnboardingStep { profile, vehicle, preferences, calendar }

enum StepStatus { done, skipped }

class Home {
  const Home({required this.address, required this.lat, required this.lon});

  factory Home.fromJson(Map<String, dynamic> json) => Home(
    address: json['address'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );

  final String address;
  final double lat;
  final double lon;
}

class Vehicle {
  const Vehicle({
    required this.consumptionLPer100km,
    required this.defaultSeats,
    required this.maxDetourMinutes,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    consumptionLPer100km: (json['consumptionLPer100km'] as num).toDouble(),
    defaultSeats: json['defaultSeats'] as int,
    maxDetourMinutes: json['maxDetourMinutes'] as int,
  );

  final double consumptionLPer100km;
  final int defaultSeats;
  final int maxDetourMinutes;

  Map<String, Object> toJson() => {
    'consumptionLPer100km': consumptionLPer100km,
    'defaultSeats': defaultSeats,
    'maxDetourMinutes': maxDetourMinutes,
  };
}

class Me {
  const Me({
    required this.id,
    required this.universityEmail,
    required this.firstName,
    required this.lastName,
    required this.home,
    required this.roleMode,
    required this.vehicle,
    required this.steps,
    required this.nextStep,
    required this.onboardingCompleted,
    required this.discoveryMode,
    required this.pausedToday,
  });

  factory Me.fromJson(Map<String, dynamic> json) {
    final onboarding = json['onboarding'] as Map<String, dynamic>;
    final rawSteps = onboarding['steps'] as Map<String, dynamic>;
    final next = onboarding['nextStep'] as String?;
    return Me(
      id: json['id'] as String,
      universityEmail: json['universityEmail'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      home: json['home'] == null ? null : Home.fromJson(json['home'] as Map<String, dynamic>),
      roleMode: RoleMode.fromWire(json['roleMode'] as String),
      vehicle: json['vehicle'] == null
          ? null
          : Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
      steps: {
        for (final step in OnboardingStep.values)
          if (rawSteps[step.name] != null)
            step: StepStatus.values.byName(rawSteps[step.name] as String),
      },
      nextStep: next == null ? null : OnboardingStep.values.byName(next),
      onboardingCompleted: onboarding['completed'] as bool,
      discoveryMode: json['discoveryMode'] as bool,
      pausedToday: json['pausedToday'] as bool,
    );
  }

  final String id;
  final String universityEmail;
  final String firstName;
  final String lastName;
  final Home? home;
  final RoleMode roleMode;
  final Vehicle? vehicle;
  final Map<OnboardingStep, StepStatus> steps;
  final OnboardingStep? nextStep;
  final bool onboardingCompleted;
  final bool discoveryMode;
  final bool pausedToday;
}

/// Pause programmée ; `everyWeeks` : une semaine sur N (alternance), `null` : continue.
class Pause {
  const Pause({required this.id, required this.startsOn, required this.endsOn, this.everyWeeks});

  factory Pause.fromJson(Map<String, dynamic> json) {
    final recurrence = json['recurrence'] as String?;
    return Pause(
      id: json['id'] as String,
      startsOn: DateTime.parse(json['startsOn'] as String),
      endsOn: DateTime.parse(json['endsOn'] as String),
      everyWeeks: recurrence == null ? null : int.parse(recurrence.split(':').last),
    );
  }

  final String id;
  final DateTime startsOn;
  final DateTime endsOn;
  final int? everyWeeks;

  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Map<String, Object?> requestBody(DateTime startsOn, DateTime endsOn, int? everyWeeks) => {
    'startsOn': isoDate(startsOn),
    'endsOn': isoDate(endsOn),
    'recurrence': everyWeeks == null ? null : 'weekly:$everyWeeks',
  };
}
