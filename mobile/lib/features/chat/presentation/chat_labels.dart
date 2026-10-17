import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../proposals/presentation/formatting.dart';
import '../domain/chat.dart';

/// Titre d'une conversation : nom du groupe, prénom de l'autre personne, ou chat du trajet.
String conversationTitle(AppLocalizations l10n, Conversation c, String? me) => switch (c.kind) {
  ConversationKind.group => c.title ?? l10n.chatGroup,
  ConversationKind.ride => switch ((c.rideDay, c.rideToCampus)) {
    (final day?, final toCampus?) =>
      toCampus
          ? l10n.proposalTitleTo(formatDayInline(day, l10n.localeName))
          : l10n.proposalTitleFrom(formatDayInline(day, l10n.localeName)),
    _ => l10n.chatRideTitle,
  },
  ConversationKind.direct => c.others(me).map((m) => m.firstName).join(', '),
};

/// Membres en clair (prénoms), sans soi-même.
String conversationMembers(AppLocalizations l10n, Conversation c, String? me) =>
    l10n.chatWith(c.others(me).map((m) => m.firstName).join(', '));

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

/// Liste : l'heure pour un message du jour, « Hier », sinon la date courte.
String formatMessageWhen(AppLocalizations l10n, DateTime at, DateTime now) {
  final local = at.toLocal();
  final days = _date(now).difference(_date(local)).inDays;
  if (days == 0) return formatTime(local, l10n.localeName);
  if (days == 1) return l10n.chatYesterday;
  return DateFormat('d MMM', l10n.localeName).format(local);
}

/// Séparateur de jour dans une conversation.
String formatMessageDay(AppLocalizations l10n, DateTime at, DateTime now) {
  final local = at.toLocal();
  final days = _date(now).difference(_date(local)).inDays;
  if (days == 0) return l10n.chatToday;
  if (days == 1) return l10n.chatYesterday;
  return formatDay(local, l10n.localeName);
}

bool sameDay(DateTime a, DateTime b) => _date(a.toLocal()) == _date(b.toLocal());
