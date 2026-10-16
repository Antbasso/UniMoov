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

/// Clôture pour tout le trajet (le suivi s'arrête pour tous) : confirmation avant.
Future<bool> confirmFinish(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.finishConfirmTitle),
      content: Text(l10n.finishConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.finishConfirmCancel),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.finishRide)),
      ],
    ),
  );
  return confirmed ?? false;
}
