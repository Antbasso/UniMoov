/// Confiance (cahier §7, §8, §10) : annulations, notes, score de fiabilité, litiges,
/// signalements. Le serveur calcule tout ; l'app affiche et transmet.
library;

/// Palier de pénalité d'une annulation selon le délai avant le trajet.
enum CancelTier { early, medium, late }

class CancellationInfo {
  const CancellationInfo({required this.isDriver, required this.tier});

  factory CancellationInfo.fromJson(Map<String, dynamic> json) => CancellationInfo(
    isDriver: json['role'] == 'driver',
    tier: CancelTier.values.byName(json['tier'] as String),
  );

  final bool isDriver;
  final CancelTier tier;
}

/// Personne à noter après un trajet (conducteur ↔ passagers présents).
class RatingTarget {
  const RatingTarget({
    required this.userId,
    required this.firstName,
    required this.isDriver,
    this.photoUrl,
    this.stars,
  });

  factory RatingTarget.fromJson(Map<String, dynamic> json) => RatingTarget(
    userId: json['userId'] as String,
    firstName: json['firstName'] as String,
    photoUrl: json['photoUrl'] as String?,
    isDriver: json['role'] == 'driver',
    stars: json['stars'] as int?,
  );

  final String userId;
  final String firstName;
  final String? photoUrl;
  final bool isDriver;

  /// Note déjà donnée, ou `null`.
  final int? stars;

  RatingTarget withStars(int value) => RatingTarget(
    userId: userId,
    firstName: firstName,
    photoUrl: photoUrl,
    isDriver: isDriver,
    stars: value,
  );
}

class RideRatings {
  const RideRatings({required this.open, required this.people});

  factory RideRatings.fromJson(Map<String, dynamic> json) => RideRatings(
    open: json['open'] as bool,
    people: [
      for (final p in json['people'] as List<dynamic>)
        RatingTarget.fromJson(p as Map<String, dynamic>),
    ],
  );

  final bool open;
  final List<RatingTarget> people;
}

enum DisputeReason {
  cancellationPenalty('cancellation_penalty'),
  markedAbsent('marked_absent'),
  payment('payment'),
  driverIssue('driver_issue'),
  other('other');

  const DisputeReason(this.wire);
  final String wire;

  static DisputeReason fromWire(String value) => values.firstWhere((r) => r.wire == value);
}

/// Entrée du score affichée (les trajets menés à bien sont seulement comptés).
enum ReliabilityEventKind {
  cancelEarly('cancel_early'),
  cancelMedium('cancel_medium'),
  cancelLate('cancel_late'),
  noShow('no_show'),
  correction('correction');

  const ReliabilityEventKind(this.wire);
  final String wire;

  static ReliabilityEventKind fromWire(String value) => values.firstWhere((k) => k.wire == value);
}

class ReliabilityEvent {
  const ReliabilityEvent({
    required this.kind,
    required this.createdAt,
    this.rideId,
    this.day,
    this.disputeReason,
  });

  factory ReliabilityEvent.fromJson(Map<String, dynamic> json) => ReliabilityEvent(
    kind: ReliabilityEventKind.fromWire(json['kind'] as String),
    rideId: json['rideId'] as String?,
    day: json['day'] == null ? null : DateTime.parse(json['day'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    disputeReason: json['disputeReason'] == null
        ? null
        : DisputeReason.fromWire(json['disputeReason'] as String),
  );

  final ReliabilityEventKind kind;
  final String? rideId;
  final DateTime? day;
  final DateTime createdAt;

  /// Motif de litige possible pour cette entrée, ou `null` si elle n'est plus contestable.
  final DisputeReason? disputeReason;
}

class Reliability {
  const Reliability({
    required this.score,
    required this.windowDays,
    required this.completedRides,
    required this.cancellations,
    required this.noShows,
    required this.ratingsCount,
    required this.events,
    this.averageStars,
  });

  factory Reliability.fromJson(Map<String, dynamic> json) {
    final cancellations = json['cancellations'] as Map<String, dynamic>;
    return Reliability(
      score: (json['score'] as num).toDouble(),
      windowDays: json['windowDays'] as int,
      completedRides: json['completedRides'] as int,
      cancellations:
          (cancellations['early'] as int) +
          (cancellations['medium'] as int) +
          (cancellations['late'] as int),
      noShows: json['noShows'] as int,
      ratingsCount: json['ratingsCount'] as int,
      averageStars: (json['averageStars'] as num?)?.toDouble(),
      events: [
        for (final e in json['events'] as List<dynamic>)
          ReliabilityEvent.fromJson(e as Map<String, dynamic>),
      ],
    );
  }

  /// Entre 0 et 1.
  final double score;
  final int windowDays;
  final int completedRides;
  final int cancellations;
  final int noShows;
  final int ratingsCount;
  final double? averageStars;
  final List<ReliabilityEvent> events;
}

enum DisputeDecision { upheld, corrected, escalated }

class Dispute {
  const Dispute({
    required this.id,
    required this.reason,
    required this.level,
    required this.decision,
    required this.explanation,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
    id: json['id'] as String,
    reason: DisputeReason.fromWire(json['reason'] as String),
    level: json['level'] as int,
    decision: DisputeDecision.values.byName(json['decision'] as String),
    explanation: json['explanation'] as String,
  );

  final String id;
  final DisputeReason reason;

  /// 1 : tranché automatiquement ; 2 : transmis à l'équipe.
  final int level;
  final DisputeDecision decision;

  /// Code d'explication du serveur (traduit par l'écran).
  final String explanation;

  bool get withTeam => level >= 2;
}

enum ReportReason {
  dangerousDriving('dangerous_driving'),
  inappropriateBehaviour('inappropriate_behaviour'),
  fakeProfile('fake_profile'),
  other('other');

  const ReportReason(this.wire);
  final String wire;
}
