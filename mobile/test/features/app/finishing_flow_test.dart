import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/core/theme/um_theme.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/rides/presentation/ride_map.dart';
import 'package:unimoov/l10n/app_localizations.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

/// Finitions : lien d'agenda collé depuis le profil, charte, bouton « Voir le véhicule ».
void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;

  setUp(() {
    backend = rideBackend();
    storage = MemoryTokenStorage()..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });

  testWidgets(
    'profil → emploi du temps → lien ICS : l’écran s’ouvre, « Coller » remplit le champ',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.getData') return {'text': FakeBackend.validIcs};
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await launchApp(tester, backend: backend, storage: storage);
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRoutes.profileSchedule);
      await tester.pumpAndSettle();
      await tapText(tester, 'Coller mon lien d\'agenda (ICS)');
      // Avant la correction, l'écran s'ouvrait sous celui de l'agenda : rien de visible.
      expect(find.text('Lien ICS'), findsOneWidget);
      await tapText(tester, 'Coller le lien copié');
      expect(find.text(FakeBackend.validIcs), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tapText(tester, 'Enregistrer');
      expect(backend.connection, isNotNull);
    },
  );

  testWidgets('charte de bonne conduite : depuis le profil, neuf sections', (tester) async {
    await launchApp(tester, backend: backend, storage: storage);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRoutes.profile);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Charte de bonne conduite'), 300);
    await tapText(tester, 'Charte de bonne conduite');
    expect(find.text('1. Respect et bienveillance'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('9. En cas de manquement'), 300);
    expect(find.text('9. En cas de manquement'), findsOneWidget);
  });

  testWidgets('carte d’un trajet en cours : bouton « Voir le véhicule » dans le coin', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rasterTilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(
          theme: buildUmTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(
            body: RideMap(
              stops: [],
              route: [(45.90, 6.10), (45.92, 6.16)],
              semanticLabel: 'Carte',
              live: LatLng(45.91, 6.12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Voir le véhicule'), findsOneWidget);
    await tester.tap(find.byTooltip('Voir le véhicule'));
    await tester.pumpAndSettle();
  });
}
