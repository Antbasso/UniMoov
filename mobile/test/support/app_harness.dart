import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/app.dart';
import 'package:unimoov/core/clock.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/core/widgets/widgets.dart';
import 'package:unimoov/features/account/data/account_api.dart';
import 'package:unimoov/features/account/data/export_sharer.dart';
import 'package:unimoov/features/auth/data/auth_api.dart';
import 'package:unimoov/features/profile/data/profile_api.dart';
import 'package:unimoov/features/proposals/data/proposals_api.dart';
import 'package:unimoov/core/location/location_service.dart';
import 'package:unimoov/features/rides/data/live_channel.dart';
import 'package:unimoov/features/rides/data/nav_launcher.dart';
import 'package:unimoov/features/rides/data/rides_api.dart';
import 'package:unimoov/features/rides/presentation/ride_map.dart';
import 'package:unimoov/features/chat/data/chat_api.dart';
import 'package:unimoov/features/chat/data/user_socket.dart';
import 'package:unimoov/features/notifications/data/notifications_api.dart';
import 'package:unimoov/features/notifications/data/push_service.dart';
import 'package:unimoov/features/trust/data/trust_api.dart';
import 'package:unimoov/features/wallet/data/wallet_api.dart';
import 'package:unimoov/features/schedule/data/schedule_api.dart';

import 'fake_backend.dart';
import 'chat_fakes.dart';
import 'live_fakes.dart';

/// Lance l'app complète sur un faux backend ; appeler deux fois simule un redémarrage
/// (nouvel état Riverpod, même stockage de jetons, même serveur).
Future<void> launchApp(
  WidgetTester tester, {
  required FakeBackend backend,
  required MemoryTokenStorage storage,
  ThemeMode themeMode = ThemeMode.light,
  DateTime? now,
  DateTime Function()? clock,
  FakeLiveConnector? live,
  FakeLocationService? location,
  FakeNavLauncher? launcher,
  PushService? push,
  ExportSharer? sharer,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // Animations en boucle (trajet en cours) coupées, comme avec le réglage d'accessibilité.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
  );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authApiProvider.overrideWithValue(backend),
        profileApiProvider.overrideWithValue(backend),
        scheduleApiProvider.overrideWithValue(backend),
        proposalsApiProvider.overrideWithValue(backend),
        ridesApiProvider.overrideWithValue(backend),
        walletApiProvider.overrideWithValue(backend),
        trustApiProvider.overrideWithValue(backend),
        chatApiProvider.overrideWithValue(backend),
        notificationsApiProvider.overrideWithValue(backend),
        accountApiProvider.overrideWithValue(backend),
        exportSharerProvider.overrideWithValue(sharer ?? FakeExportSharer()),
        userSocketConnectorProvider.overrideWithValue(backend.socket),
        pushServiceProvider.overrideWithValue(push ?? FakePushService()),
        liveConnectorProvider.overrideWithValue(live ?? FakeLiveConnector()),
        locationServiceProvider.overrideWithValue(location ?? FakeLocationService()),
        navLauncherProvider.overrideWithValue(launcher ?? FakeNavLauncher()),
        // Pas de tuiles réseau dans les tests (goldens stables).
        rasterTilesEnabledProvider.overrideWithValue(false),
        // Date figée : goldens et semaines stables quel que soit le jour du test.
        clockProvider.overrideWithValue(clock ?? () => now ?? testNow),
      ],
      child: UniMoovApp(themeMode: themeMode),
    ),
  );
  await tester.pumpAndSettle();
}

/// Jeudi 15 octobre 2026, 10 h : date de référence des tests.
final testNow = DateTime(2026, 10, 15, 10);

/// Champ de saisie d'un [UmField] repéré par son libellé visible.
Finder fieldLabeled(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(UmField)),
  matching: find.byType(TextField),
);

/// Touche un texte visible ; `index` choisit parmi plusieurs occurrences.
Future<void> tapText(WidgetTester tester, String text, {int? index}) async {
  final target = index == null ? find.text(text) : find.text(text).at(index);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
