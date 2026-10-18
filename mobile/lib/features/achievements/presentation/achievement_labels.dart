import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Nom d'un niveau (« Super Uni-Mooveur »).
String levelName(AppLocalizations l10n, String key) => switch (key) {
  'regular' => l10n.levelRegular,
  'pillar' => l10n.levelPillar,
  'super' => l10n.levelSuper,
  'legend' => l10n.levelLegend,
  _ => l10n.levelNewcomer,
};

String badgeName(AppLocalizations l10n, String key) => switch (key) {
  'first_ride' => l10n.badgeFirstRide,
  'ten_rides' => l10n.badgeTenRides,
  'fifty_rides' => l10n.badgeFiftyRides,
  'loyal_driver' => l10n.badgeLoyalDriver,
  'full_week' => l10n.badgeFullWeek,
  'sociable' => l10n.badgeSociable,
  'eco' => l10n.badgeEco,
  'reliable' => l10n.badgeReliable,
  _ => key,
};

/// Ce qu'il faut faire pour gagner le badge.
String badgeGoal(AppLocalizations l10n, String key) => switch (key) {
  'first_ride' => l10n.badgeFirstRideGoal,
  'ten_rides' => l10n.badgeTenRidesGoal,
  'fifty_rides' => l10n.badgeFiftyRidesGoal,
  'loyal_driver' => l10n.badgeLoyalDriverGoal,
  'full_week' => l10n.badgeFullWeekGoal,
  'sociable' => l10n.badgeSociableGoal,
  'eco' => l10n.badgeEcoGoal,
  'reliable' => l10n.badgeReliableGoal,
  _ => '',
};

IconData badgeIcon(String key) => switch (key) {
  'first_ride' => Icons.flag_rounded,
  'ten_rides' => Icons.emoji_events_outlined,
  'fifty_rides' => Icons.military_tech_rounded,
  'loyal_driver' => Icons.directions_car_filled_rounded,
  'full_week' => Icons.calendar_month_rounded,
  'sociable' => Icons.groups_rounded,
  'eco' => Icons.eco_rounded,
  'reliable' => Icons.verified_rounded,
  _ => Icons.emoji_events_rounded,
};

/// Icône du niveau (couronne de laurier façon « Super Covoitureur »).
IconData levelIcon(String key) => switch (key) {
  'legend' => Icons.workspace_premium_rounded,
  'super' => Icons.emoji_events_rounded,
  'pillar' => Icons.star_rounded,
  'regular' => Icons.thumb_up_alt_rounded,
  _ => Icons.spa_rounded,
};
