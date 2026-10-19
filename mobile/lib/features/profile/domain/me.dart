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
    this.model,
    this.color,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    consumptionLPer100km: (json['consumptionLPer100km'] as num).toDouble(),
    defaultSeats: json['defaultSeats'] as int,
    maxDetourMinutes: json['maxDetourMinutes'] as int,
    model: json['model'] as String?,
    color: json['color'] as String?,
  );

  final double consumptionLPer100km;
  final int defaultSeats;
  final int maxDetourMinutes;

  /// Modèle (« Renault Clio ») et couleur (« grise ») : les passagers reconnaissent la voiture.
  final String? model;
  final String? color;

  Map<String, Object?> toJson() => {
    'consumptionLPer100km': consumptionLPer100km,
    'defaultSeats': defaultSeats,
    'maxDetourMinutes': maxDetourMinutes,
    'model': model,
    'color': color,
  };
}

/// Préférences de covoiturage montrées sur le profil (valeurs de l'API, null : non précisé).
class CarpoolPreferences {
  const CarpoolPreferences({this.chat, this.music, this.smoking, this.pets});

  factory CarpoolPreferences.fromJson(Map<String, dynamic>? json) => CarpoolPreferences(
    chat: json?['chat'] as String?,
    music: json?['music'] as String?,
    smoking: json?['smoking'] as String?,
    pets: json?['pets'] as String?,
  );

  /// Valeurs possibles de chaque préférence, dans l'ordre affiché.
  static const chatValues = ['chatty', 'depends', 'quiet'];
  static const musicValues = ['yes', 'depends', 'no'];
  static const smokingValues = ['ok', 'outside', 'no'];
  static const petsValues = ['yes', 'some', 'no'];

  final String? chat;
  final String? music;
  final String? smoking;
  final String? pets;

  bool get isEmpty => chat == null && music == null && smoking == null && pets == null;

  /// Une préférence changée (la fonction rend la nouvelle valeur, `null` compris).
  CarpoolPreferences copyWith({
    String? Function()? chat,
    String? Function()? music,
    String? Function()? smoking,
    String? Function()? pets,
  }) => CarpoolPreferences(
    chat: chat == null ? this.chat : chat(),
    music: music == null ? this.music : music(),
    smoking: smoking == null ? this.smoking : smoking(),
    pets: pets == null ? this.pets : pets(),
  );

  Map<String, Object?> toJson() => {'chat': chat, 'music': music, 'smoking': smoking, 'pets': pets};
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
    this.defaultNavApp,
    this.photoUrl,
    this.studyProgram,
    this.birthYear,
    this.interests = const [],
    this.bio,
    this.preferences = const CarpoolPreferences(),
    this.leaderboardVisible = false,
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
      defaultNavApp: json['defaultNavApp'] as String?,
      photoUrl: json['photoUrl'] as String?,
      studyProgram: json['studyProgram'] as String?,
      birthYear: json['birthYear'] as int?,
      interests: [for (final i in json['interests'] as List<dynamic>? ?? const []) i as String],
      bio: json['bio'] as String?,
      preferences: CarpoolPreferences.fromJson(json['preferences'] as Map<String, dynamic>?),
      leaderboardVisible: json['leaderboardVisible'] as bool? ?? false,
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

  /// Application GPS choisie au premier départ (`google_maps`, `waze`, `apple_maps`).
  final String? defaultNavApp;

  /// Photo de profil (chemin de l'API, chargé avec le jeton).
  final String? photoUrl;

  /// Visible par les personnes croisées : formation, âge (année de naissance), centres d'intérêt.
  final String? studyProgram;
  final int? birthYear;
  final List<String> interests;

  /// Mini-bio (200 caractères) et préférences de covoiturage, montrées sur le profil.
  final String? bio;
  final CarpoolPreferences preferences;

  /// Prénom et photo visibles dans le classement du campus (sinon ligne anonyme).
  final bool leaderboardVisible;
}

/// Profil d'une personne croisée sur un trajet ou dans une conversation (`GET /users/{id}/public`).
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.firstName,
    required this.reliabilityScore,
    required this.ridesCompleted,
    this.photoUrl,
    this.age,
    this.studyProgram,
    this.interests = const [],
    this.bio,
    this.preferences = const CarpoolPreferences(),
    this.memberSince,
    this.ratingsCount = 0,
    this.cancellationRate = 0,
    this.levelKey = 'newcomer',
    this.points = 0,
    this.badges = const [],
    this.co2SavedKg = 0,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    photoUrl: json['photoUrl'] as String?,
    reliabilityScore: (json['reliabilityScore'] as num).toDouble(),
    age: json['age'] as int?,
    studyProgram: json['studyProgram'] as String?,
    interests: [for (final i in json['interests'] as List<dynamic>) i as String],
    ridesCompleted: json['ridesCompleted'] as int,
    bio: json['bio'] as String?,
    preferences: CarpoolPreferences.fromJson(json['preferences'] as Map<String, dynamic>?),
    memberSince: switch (json['memberSince']) {
      final String month => DateTime.tryParse('$month-01'),
      _ => null,
    },
    ratingsCount: json['ratingsCount'] as int? ?? 0,
    cancellationRate: json['cancellationRate'] as int? ?? 0,
    levelKey: (json['level'] as Map<String, dynamic>?)?['key'] as String? ?? 'newcomer',
    points: (json['level'] as Map<String, dynamic>?)?['points'] as int? ?? 0,
    badges: [for (final b in json['badges'] as List<dynamic>? ?? const []) b as String],
    co2SavedKg: json['co2SavedKg'] as int? ?? 0,
  );

  final String id;
  final String firstName;
  final String? photoUrl;
  final double reliabilityScore;
  final int? age;
  final String? studyProgram;
  final List<String> interests;
  final int ridesCompleted;
  final String? bio;
  final CarpoolPreferences preferences;

  /// Mois d'inscription (premier du mois).
  final DateTime? memberSince;
  final int ratingsCount;

  /// Part des trajets acceptés puis annulés, en pour cent.
  final int cancellationRate;
  final String levelKey;
  final int points;

  /// Badges gagnés (clés).
  final List<String> badges;
  final int co2SavedKg;

  String get scoreOutOfFive => (reliabilityScore * 5).toStringAsFixed(1).replaceAll('.', ',');
}

/// Répétition d'une pause, comme un événement d'agenda (cahier §12, docs/api.md).
sealed class PauseRepeat {
  const PauseRepeat();

  static PauseRepeat? fromWire(String? wire) {
    if (wire == null) return null;
    final [kind, value] = wire.split(':');
    return switch (kind) {
      'weekly' => RepeatWeekly(int.parse(value)),
      'monthly' => RepeatMonthly(int.parse(value)),
      'days' => RepeatDays({for (final d in value.split(',')) int.parse(d)}),
      _ => null,
    };
  }

  String get wire;
}

/// La première occurrence revient toutes les `every` semaines (1 : chaque semaine).
class RepeatWeekly extends PauseRepeat {
  const RepeatWeekly(this.every);
  final int every;
  @override
  String get wire => 'weekly:$every';
}

/// La première occurrence revient tous les `every` mois, au même jour du mois.
class RepeatMonthly extends PauseRepeat {
  const RepeatMonthly(this.every);
  final int every;
  @override
  String get wire => 'monthly:$every';
}

/// Chaque semaine, les jours ISO donnés (1 = lundi).
class RepeatDays extends PauseRepeat {
  const RepeatDays(this.weekdays);
  final Set<int> weekdays;
  @override
  String get wire => 'days:${(weekdays.toList()..sort()).join(',')}';
}

/// Pause programmée : première occurrence (du `startsOn` au `endsOn`), répétée jusqu'à
/// `repeatUntil` si `repeat` est donné.
class Pause {
  const Pause({
    required this.id,
    required this.startsOn,
    required this.endsOn,
    this.repeat,
    this.repeatUntil,
  });

  factory Pause.fromJson(Map<String, dynamic> json) => Pause(
    id: json['id'] as String,
    startsOn: DateTime.parse(json['startsOn'] as String),
    endsOn: DateTime.parse(json['endsOn'] as String),
    repeat: PauseRepeat.fromWire(json['recurrence'] as String?),
    repeatUntil: json['repeatUntil'] == null ? null : DateTime.parse(json['repeatUntil'] as String),
  );

  final String id;
  final DateTime startsOn;
  final DateTime endsOn;
  final PauseRepeat? repeat;
  final DateTime? repeatUntil;

  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Pause à créer.
class PauseDraft {
  const PauseDraft({required this.startsOn, required this.endsOn, this.repeat, this.repeatUntil});

  final DateTime startsOn;
  final DateTime endsOn;
  final PauseRepeat? repeat;
  final DateTime? repeatUntil;

  Map<String, Object?> toJson() => {
    'startsOn': Pause.isoDate(startsOn),
    'endsOn': Pause.isoDate(endsOn),
    'recurrence': repeat?.wire,
    'repeatUntil': repeat == null || repeatUntil == null ? null : Pause.isoDate(repeatUntil!),
  };

  /// Même règle que le serveur : la première occurrence tient dans sa période.
  bool get fitsPeriod => switch (repeat) {
    RepeatWeekly(:final every) => endsOn.difference(startsOn).inDays < 7 * every,
    RepeatMonthly() => endsOn.difference(startsOn).inDays < 28,
    _ => true,
  };
}

/// Même règle que le serveur (backend/src/modules/profile/domain.ts) : la pause couvre-t-elle
/// ce jour ? Sert au mode démo, qui n'a pas de serveur.
bool pauseCovers({
  required DateTime startsOn,
  required DateTime endsOn,
  required PauseRepeat? repeat,
  required DateTime? repeatUntil,
  required DateTime day,
}) {
  int days(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
  final today = days(day);
  final start = days(startsOn);
  final length = days(endsOn) - start + 1;
  if (today < start) return false;
  if (repeat == null || repeatUntil == null) return today < start + length;
  if (today > days(repeatUntil)) return false;
  switch (repeat) {
    case RepeatDays(:final weekdays):
      return weekdays.contains(day.weekday);
    case RepeatWeekly(:final every):
      return (today - start) % (7 * every) < length;
    case RepeatMonthly(:final every):
      for (var k = 0; ; k += every) {
        final lastDay = DateTime.utc(startsOn.year, startsOn.month + k + 1, 0).day;
        final occurrence = days(
          DateTime.utc(
            startsOn.year,
            startsOn.month + k,
            startsOn.day > lastDay ? lastDay : startsOn.day,
          ),
        );
        if (occurrence > today) return false;
        if (today < occurrence + length) return true;
      }
  }
}
