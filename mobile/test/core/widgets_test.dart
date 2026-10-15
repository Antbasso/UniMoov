import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/theme/um_theme.dart';
import 'package:unimoov/core/widgets/widgets.dart';

import '../helpers.dart';

void main() {
  group('UmButton', () {
    for (final variant in UmButtonVariant.values) {
      testWidgets('$variant : zone tactile ≥ 48 px et accessibilité', (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          wrap(UmButton(label: 'Proposer un trajet', variant: variant, onPressed: () => taps++)),
        );
        expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
        await tester.tap(find.text('Proposer un trajet'));
        expect(taps, 1);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('affiche un anneau de focus de 3 px', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        wrap(
          Focus(
            focusNode: focusNode,
            child: UmButton(label: 'Valider', onPressed: () {}),
          ),
        ),
      );
      final button = tester.widget<TextButton>(find.byType(TextButton));
      final side = button.style!.side!.resolve({WidgetState.focused});
      expect(side!.width, 3);
      expect(side.color, UmColorTokens.light.focus);
      focusNode.dispose();
    });
  });

  group('UmChip', () {
    testWidgets('un statut affiche un mot et une icône', (tester) async {
      await tester.pumpWidget(
        wrap(const UmChip(label: 'Confirmé', icon: Icons.check, tone: UmChipTone.success)),
      );
      expect(find.text('Confirmé'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    test('un statut sans icône est refusé', () {
      expect(() => UmChip(label: 'Annulé', tone: UmChipTone.danger), throwsAssertionError);
    });
  });

  group('UmField', () {
    testWidgets('préfixe l’erreur par le mot « Erreur »', (tester) async {
      await tester.pumpWidget(
        wrap(const UmField(label: 'Mail universitaire', error: 'adresse invalide')),
      );
      expect(find.text('Mail universitaire'), findsOneWidget);
      expect(find.text('Erreur : adresse invalide'), findsOneWidget);
    });

    testWidgets('affiche l’aide sans erreur et respecte 48 px', (tester) async {
      await tester.pumpWidget(wrap(const UmField(label: 'Prénom', help: 'Visible par les autres')));
      expect(find.text('Visible par les autres'), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(48));
    });
  });

  group('UmCard et UmBenefit', () {
    testWidgets('la carte cadre garde un fond clair en thème sombre', (tester) async {
      await tester.pumpWidget(
        wrap(const UmCard.frame(child: Text('QR')), brightness: Brightness.dark),
      );
      final inner = tester
          .widgetList<Container>(
            find.ancestor(of: find.text('QR'), matching: find.byType(Container)),
          )
          .first;
      expect((inner.decoration! as BoxDecoration).color, UmColorTokens.light.surfaceRaised);
    });

    test('les bénéfices vont par trois', () {
      expect(
        () => UmBenefitRow(
          benefits: const [UmBenefit(icon: Icons.schedule, label: 'a')],
        ),
        throwsAssertionError,
      );
    });
  });

  group('UmRideCard', () {
    testWidgets('affiche lieux, prix en euros et statut', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            child: UmRideCard(
              from: 'Seynod',
              to: 'Campus d’Annecy',
              time: 'Demain, 8h15',
              driverFirstName: 'Léa',
              seatsLeft: 2,
              priceCents: 240,
              status: UmRideStatus.cancelled,
              actionLabel: 'Voir',
              onAction: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Seynod'), findsOneWidget);
      expect(find.textContaining('2 places libres'), findsOneWidget);
      expect(find.text('2,40 €'), findsOneWidget);
      expect(find.text('Annulé'), findsOneWidget);
      await tester.tap(find.text('Voir'));
      expect(taps, 1);
    });

    test('formate les centimes sans flottant visible', () {
      expect(UmRideCard.formatPrice(5, 'fr'), '0,05 €');
      expect(UmRideCard.formatPrice(123456, 'fr'), '1 234,56 €');
    });
  });
}
