import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:unimoov/core/router/redirect.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/core/theme/um_theme.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/rides/domain/ride.dart';
import 'package:unimoov/features/rides/presentation/ride_map.dart';
import 'package:unimoov/l10n/app_localizations.dart';

import '../../support/app_harness.dart';
import '../../support/fake_backend.dart';

/// Finitions : lien d'agenda collé depuis le profil, charte, suivi du véhicule sur la carte.
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

  testWidgets('carte d’un trajet en cours : suivre le véhicule jusqu’à ce qu’on touche la carte', (
    tester,
  ) async {
    var live = const LatLng(45.91, 6.12);
    late StateSetter move;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rasterTilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(
          theme: buildUmTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                move = setState;
                return RideMap(
                  stops: const [],
                  route: const [(45.90, 6.10), (45.92, 6.16)],
                  semanticLabel: 'Carte',
                  live: live,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    LatLng center() => MapCamera.of(tester.element(find.byType(MarkerLayer))).center;
    Future<void> drive(LatLng to) async {
      move(() => live = to);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Suivre le véhicule'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.navigation_rounded), findsWidgets);
    // Le véhicule avance : la carte le suit.
    await drive(const LatLng(45.915, 6.13));
    expect(center().latitude, closeTo(45.915, 1e-6));
    expect(center().longitude, closeTo(6.13, 1e-6));
    // Un geste sur la carte arrête le suivi : elle ne bouge plus d'elle-même.
    await tester.drag(find.byType(FlutterMap), const Offset(80, 60));
    await tester.pumpAndSettle();
    final moved = center();
    await drive(const LatLng(45.918, 6.14));
    expect(center(), moved);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
  });

  testWidgets('retour : l’arrivée du conducteur est un drapeau, son départ à l’aller une voiture', (
    tester,
  ) async {
    RideStop stop(int order) => RideStop(
      order: order,
      kind: StopKind.driver,
      label: '',
      lat: 45.9,
      lon: 6.1,
      isMeetingPoint: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildUmTheme(Brightness.light),
        home: Scaffold(
          body: Row(
            children: [
              StopBadge(stop: stop(0)),
              StopBadge(stop: stop(3)),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sports_score_rounded), findsOneWidget);
  });
}
