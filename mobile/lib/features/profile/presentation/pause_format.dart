import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/me.dart';

String formatPauseDate(DateTime date, String locale) => DateFormat.yMMMd(locale).format(date);

/// « lundis », « mardis » : jour de la semaine ISO au pluriel (1 = lundi).
String weekdayPlural(int weekday, String locale) =>
    '${DateFormat.EEEE(locale).format(DateTime(2024, 1, weekday))}s';

/// « lundis, mardis et jeudis ».
String joinWithAnd(List<String> items, AppLocalizations l10n) => items.length <= 1
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} ${l10n.and} ${items.last}';

/// Une pause en une phrase, comme un événement d'agenda :
/// « Du 3 nov. au 9 nov., toutes les 2 semaines, jusqu'au 30 juin », « Tous les lundis
/// jusqu'au 30 juin ».
String describePause({
  required DateTime startsOn,
  required DateTime endsOn,
  required PauseRepeat? repeat,
  required DateTime? repeatUntil,
  required AppLocalizations l10n,
}) {
  final locale = l10n.localeName;
  String date(DateTime d) => formatPauseDate(d, locale);
  final range = startsOn == endsOn
      ? l10n.pauseOn(date(startsOn))
      : l10n.pauseRange(date(startsOn), date(endsOn));
  final until = repeatUntil == null ? '' : ' ${l10n.pauseUntil(date(repeatUntil))}';
  return switch (repeat) {
    null => range,
    RepeatDays(:final weekdays) =>
      l10n.pauseEveryWeekdays(
            joinWithAnd([
              for (final d in weekdays.toList()..sort()) weekdayPlural(d, locale),
            ], l10n),
          ) +
          until,
    RepeatWeekly(every: 1) when startsOn == endsOn =>
      l10n.pauseEveryWeekdays(weekdayPlural(startsOn.weekday, locale)) + until,
    RepeatWeekly(:final every) => '$range, ${l10n.pauseEveryWeeks(every)},$until',
    RepeatMonthly(:final every) => '$range, ${l10n.pauseEveryMonths(every)},$until',
  };
}
