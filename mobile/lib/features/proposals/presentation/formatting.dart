import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/proposal.dart';

/// « lundi 19 octobre », pour une phrase (casse de phrase).
String formatDayInline(DateTime day, String locale) =>
    DateFormat('EEEE d MMMM', locale).format(day);

/// « Lundi 19 octobre », en début de ligne (titre de groupe, puce).
String formatDay(DateTime day, String locale) {
  final text = formatDayInline(day, locale);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// « 8 h 15 », usage français (heure du téléphone, en France au pilote).
String formatTime(DateTime time, String locale) =>
    DateFormat("H 'h' mm", locale).format(time.toLocal());

UmRideStatus rideStatusOf(Proposal p) => switch (p.state) {
  ProposalState.proposed => UmRideStatus.proposed,
  ProposalState.waiting => UmRideStatus.waiting,
  ProposalState.confirmed => UmRideStatus.confirmed,
  ProposalState.cancelled => UmRideStatus.cancelled,
};

/// Départ et arrivée affichés sur la carte de trajet, sans adresse exacte.
(String from, String to) endpoints(
  AppLocalizations l10n,
  Direction direction, {
  required bool driver,
}) {
  final home = driver ? l10n.yourHome : l10n.nearYourHome;
  return direction == Direction.toCampus ? (home, l10n.campusName) : (l10n.campusName, home);
}
