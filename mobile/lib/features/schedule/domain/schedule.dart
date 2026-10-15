/// Agenda connecté (le lien ICS n'est jamais renvoyé par l'API).
class CalendarConnection {
  const CalendarConnection({
    required this.id,
    required this.consentedAt,
    this.lastSyncedAt,
    this.lastError,
  });

  factory CalendarConnection.fromJson(Map<String, dynamic> json) => CalendarConnection(
    id: json['id'] as String,
    consentedAt: DateTime.parse(json['consentedAt'] as String),
    lastSyncedAt: json['lastSyncedAt'] == null
        ? null
        : DateTime.parse(json['lastSyncedAt'] as String),
    lastError: json['lastError'] as String?,
  );

  final String id;
  final DateTime consentedAt;
  final DateTime? lastSyncedAt;
  final String? lastError;
}

/// Jour de la semaine type : `weekday` ISO (1 = lundi), heures `HH:MM`.
class ManualDay {
  const ManualDay({required this.weekday, required this.startTime, required this.endTime});

  factory ManualDay.fromJson(Map<String, dynamic> json) => ManualDay(
    weekday: json['weekday'] as int,
    startTime: json['startTime'] as String,
    endTime: json['endTime'] as String,
  );

  final int weekday;
  final String startTime;
  final String endTime;

  Map<String, Object> toJson() => {'weekday': weekday, 'startTime': startTime, 'endTime': endTime};

  /// La fin suit le début (comparaison de chaînes `HH:MM`, valable sur 24 h).
  bool get isValid => endTime.compareTo(startTime) > 0;

  static String format(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class ScheduleState {
  const ScheduleState({required this.connection, required this.manualDays});

  final CalendarConnection? connection;
  final List<ManualDay> manualDays;

  bool get isEmpty => connection == null && manualDays.isEmpty;
}
