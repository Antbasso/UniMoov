import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/app.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/core/widgets/widgets.dart';
import 'package:unimoov/features/auth/data/auth_api.dart';
import 'package:unimoov/features/profile/data/profile_api.dart';

import 'fake_backend.dart';

/// Lance l'app complète sur un faux backend ; appeler deux fois simule un redémarrage
/// (nouvel état Riverpod, même stockage de jetons, même serveur).
Future<void> launchApp(
  WidgetTester tester, {
  required FakeBackend backend,
  required MemoryTokenStorage storage,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authApiProvider.overrideWithValue(backend),
        profileApiProvider.overrideWithValue(backend),
      ],
      child: UniMoovApp(themeMode: themeMode),
    ),
  );
  await tester.pumpAndSettle();
}

/// Champ de saisie d'un [UmField] repéré par son libellé visible.
Finder fieldLabeled(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(UmField)),
  matching: find.byType(TextField),
);

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
