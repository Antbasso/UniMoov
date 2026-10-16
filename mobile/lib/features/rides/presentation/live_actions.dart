import 'package:flutter/widgets.dart';
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
