/// Gamification (`GET /me/achievements`, `GET /leaderboard`) : points, niveau, badges, impact
/// et classement du campus. Récompenses symboliques, sans effet sur l'argent.
class AchievementBadge {
  const AchievementBadge({
    required this.key,
    required this.goal,
    required this.progress,
    required this.earned,
  });

  factory AchievementBadge.fromJson(Map<String, dynamic> json) => AchievementBadge(
    key: json['key'] as String,
    goal: json['goal'] as int,
    progress: json['progress'] as int,
    earned: json['earned'] as bool,
  );

  final String key;
  final int goal;
  final int progress;
  final bool earned;
}

class Achievements {
  const Achievements({
    required this.points,
    required this.levelKey,
    required this.levelMin,
    required this.badges,
    required this.rides,
    required this.sharedKm,
    required this.co2SavedKg,
    required this.paidCents,
    required this.receivedCents,
    required this.monthPoints,
    required this.ranked,
    required this.leaderboardVisible,
    this.nextKey,
    this.nextMin,
    this.monthRank,
  });

  factory Achievements.fromJson(Map<String, dynamic> json) {
    final level = json['level'] as Map<String, dynamic>;
    final next = level['next'] as Map<String, dynamic>?;
    final impact = json['impact'] as Map<String, dynamic>;
    final month = json['month'] as Map<String, dynamic>;
    return Achievements(
      points: json['points'] as int,
      levelKey: level['key'] as String,
      levelMin: level['min'] as int,
      nextKey: next?['key'] as String?,
      nextMin: next?['min'] as int?,
      badges: [
        for (final b in json['badges'] as List<dynamic>)
          AchievementBadge.fromJson(b as Map<String, dynamic>),
      ],
      rides: impact['rides'] as int,
      sharedKm: impact['sharedKm'] as int,
      co2SavedKg: impact['co2SavedKg'] as int,
      paidCents: impact['paidCents'] as int,
      receivedCents: impact['receivedCents'] as int,
      monthPoints: month['points'] as int,
      monthRank: month['rank'] as int?,
      ranked: month['ranked'] as int,
      leaderboardVisible: json['leaderboardVisible'] as bool,
    );
  }

  final int points;
  final String levelKey;
  final int levelMin;
  final String? nextKey;
  final int? nextMin;
  final List<AchievementBadge> badges;
  final int rides;
  final int sharedKm;
  final int co2SavedKg;
  final int paidCents;
  final int receivedCents;
  final int monthPoints;
  final int? monthRank;
  final int ranked;
  final bool leaderboardVisible;

  /// Avancée vers le niveau suivant, de 0 à 1 (1 au dernier niveau).
  double get progress {
    final next = nextMin;
    if (next == null || next <= levelMin) return 1;
    return ((points - levelMin) / (next - levelMin)).clamp(0, 1).toDouble();
  }

  int get earnedCount => badges.where((b) => b.earned).length;
}

class LeaderEntry {
  const LeaderEntry({
    required this.rank,
    required this.points,
    required this.levelKey,
    required this.me,
    this.firstName,
    this.photoUrl,
  });

  factory LeaderEntry.fromJson(Map<String, dynamic> json) => LeaderEntry(
    rank: json['rank'] as int,
    firstName: json['firstName'] as String?,
    photoUrl: json['photoUrl'] as String?,
    points: json['points'] as int,
    levelKey: json['level'] as String,
    me: json['me'] as bool,
  );

  final int rank;

  /// Absent : la personne n'a pas choisi d'apparaître avec son prénom.
  final String? firstName;
  final String? photoUrl;
  final int points;
  final String levelKey;
  final bool me;
}

class Leaderboard {
  const Leaderboard({
    required this.month,
    required this.ranked,
    required this.entries,
    this.myRank,
    this.myPoints,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>?;
    return Leaderboard(
      month: DateTime.parse('${json['month'] as String}-01'),
      ranked: json['ranked'] as int,
      entries: [
        for (final e in json['entries'] as List<dynamic>)
          LeaderEntry.fromJson(e as Map<String, dynamic>),
      ],
      myRank: me?['rank'] as int?,
      myPoints: me?['points'] as int?,
    );
  }

  final DateTime month;
  final int ranked;
  final List<LeaderEntry> entries;
  final int? myRank;
  final int? myPoints;
}
