import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/router/redirect.dart';
import '../../../l10n/app_localizations.dart';
import 'live_controller.dart';

/// Partage de ma position : écran d'explication si la permission manque, puis envoi.
Future<void> shareLocation(BuildContext context, WidgetRef ref, String rideId) async {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final live = ref.read(liveRideProvider(rideId).notifier);
  if (await ref.read(locationServiceProvider).status() != LocationAccess.granted) {
    final granted = await router.push<bool>(AppRoutes.rideLocation(rideId));
    if (granted != true) return;
  }
  await live.startSharing(
    notificationTitle: l10n.locationNotificationTitle,
    notificationText: l10n.locationNotificationText,
  );
}

/// Conducteur : clôture pour tout le trajet (les passagers pas encore à destination ne paient
/// pas) ; confirmation avant.
Future<bool> confirmFinish(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return _confirm(context, l10n.finishConfirmTitle, l10n.finishConfirmBody, l10n.finishRide);
}

/// Passager à bord, pas encore arrivé : terminer annule la rémunération du conducteur pour lui
/// (cahier §9), qui est prévenu ; avertissement avant.
Future<bool> confirmFinishMyTrip(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return _confirm(context, l10n.finishMyTripTitle, l10n.finishMyTripBody, l10n.finishMyTripConfirm);
}

Future<bool> _confirm(BuildContext context, String title, String body, String confirm) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.finishConfirmCancel),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirm)),
      ],
    ),
  );
  return confirmed ?? false;
}
