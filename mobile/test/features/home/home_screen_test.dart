import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/app.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/features/home/data/health_repository.dart';
import 'package:unimoov/features/home/domain/api_health.dart';

class StubHealthRepository implements HealthRepository {
  StubHealthRepository(this.result);

  final Future<ApiHealth> Function() result;

  @override
  Future<ApiHealth> fetch() => result();
}

Future<void> pumpHome(
  WidgetTester tester,
  Future<ApiHealth> Function() result, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [healthRepositoryProvider.overrideWithValue(StubHealthRepository(result))],
      child: UniMoovApp(themeMode: themeMode),
    ),
  );
}

void main() {
  testWidgets('état chargement', (tester) async {
    final pending = Completer<ApiHealth>();
    await pumpHome(tester, () => pending.future);
    await tester.pump();
    expect(find.text('Connexion au serveur…'), findsOneWidget);
    pending.complete(ApiHealth.ok);
    await tester.pumpAndSettle();
  });

  testWidgets('état contenu : serveur connecté', (tester) async {
    await pumpHome(tester, () async => ApiHealth.ok);
    await tester.pumpAndSettle();
    expect(find.text('Ton emploi du temps organise aussi tes trajets.'), findsOneWidget);
    expect(find.text('Serveur connecté'), findsOneWidget);
    expect(find.bySemanticsLabel('Logo Uni-Moov'), findsOneWidget);
  });

  testWidgets('état erreur puis réessai', (tester) async {
    var calls = 0;
    await pumpHome(tester, () async {
      calls++;
      if (calls == 1) throw const ApiException('network_error', 'Serveur injoignable');
      return ApiHealth.ok;
    });
    await tester.pumpAndSettle();
    expect(find.text('Serveur injoignable'), findsOneWidget);
    await tester.ensureVisible(find.text('Réessayer'));
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Serveur connecté'), findsOneWidget);
  });

  testWidgets('une seule exclamation à l’écran', (tester) async {
    await pumpHome(tester, () async => ApiHealth.ok);
    await tester.pumpAndSettle();
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
    expect('!'.allMatches(texts).length, 1);
  });

  testWidgets('accessibilité : zones tactiles, libellés, contrastes', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester, () async => ApiHealth.ok);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  for (final (name, mode) in [('clair', ThemeMode.light), ('sombre', ThemeMode.dark)]) {
    testWidgets('golden accueil thème $name', (tester) async {
      await pumpHome(tester, () async => ApiHealth.ok, themeMode: mode);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${mode.name}.png'),
      );
    });
  }
}
