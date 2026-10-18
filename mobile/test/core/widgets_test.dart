import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('anneau de focus de 3 px hors du bouton, sans changer sa taille', (tester) async {
      await tester.pumpWidget(wrap(UmButton(label: 'Valider', onPressed: () {})));
      final before = tester.getSize(find.byType(TextButton));
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.getSize(find.byType(TextButton)), before);
      final ring = find.descendant(
        of: find.byType(UmButton),
        matching: find.byWidgetPredicate(
          (w) =>
              w is CustomPaint && w.foregroundPainter.runtimeType.toString() == '_FocusRingPainter',
        ),
      );
      expect(ring, findsOneWidget);
      // Le peintre dessine un trait de 3 px dans la couleur `focus`, décalé de 2 px.
      expect(ring, paints..rrect(color: UmColorTokens.light.focus, strokeWidth: UmSize.focusRing));
    });

    testWidgets('chargement : indicateur, appuis ignorés, libellé conservé', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(UmButton(label: 'Envoyer', loading: true, onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Envoyer'), findsOneWidget);
      await tester.tap(find.text('Envoyer'));
      expect(taps, 0);
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
    testWidgets('préfixe l’erreur par « Erreur » et l’annonce avec le champ', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const UmField(label: 'Mail universitaire', error: 'adresse invalide')),
      );
      expect(find.text('Erreur : adresse invalide'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(EditableText));
      final announced = '${semantics.label} ${semantics.hint} ${semantics.value}';
      expect(announced, contains('Mail universitaire'));
      expect(announced, contains('Erreur : adresse invalide'));
      // Le libellé visible n'est pas lu une seconde fois.
      expect(find.bySemanticsLabel('Mail universitaire'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('affiche l’aide sans erreur et respecte 48 px', (tester) async {
      await tester.pumpWidget(wrap(const UmField(label: 'Prénom', help: 'Visible par les autres')));
      expect(find.text('Visible par les autres'), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(UmSize.tapTarget));
    });

    testWidgets('mot de passe : masqué, puis affiché à la demande', (tester) async {
      await tester.pumpWidget(wrap(const UmField(label: 'Mot de passe', obscureText: true)));
      EditableText editable() => tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(editable().obscureText, isFalse);
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
    });

    testWidgets('désactivé : saisie impossible', (tester) async {
      await tester.pumpWidget(wrap(const UmField(label: 'Ville', enabled: false)));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
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

    testWidgets('titre en h3 annoncé comme en-tête, texte en ink-muted', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const UmCard(title: 'Ton trajet', body: 'Départ à 8h15')));
      final body = tester.widget<Text>(find.text('Départ à 8h15'));
      expect(body.style!.color, UmColorTokens.light.inkMuted);
      expect(tester.getSemantics(find.text('Ton trajet')).flagsCollection.isHeader, isTrue);
      handle.dispose();
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
              meta: const [(Icons.person_outline_rounded, 'Léa')],
              actionLabel: 'Choisir',
              onAction: () => taps++,
            ),
          ),
        ),
      );
      expect(find.textContaining('Seynod', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.textContaining('Léa', findRichText: true), findsOneWidget);
      expect(
        find.textContaining(UmRideCard.formatPrice(240, 'fr'), findRichText: true),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Prix estimé')), findsOneWidget);
      expect(find.text('Annulé'), findsOneWidget);
      await tester.tap(find.text('Choisir'));
      expect(taps, 1);
    });

    testWidgets('carte entière touchable, trajet en cours sur fond animé', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            child: UmRideCard(
              from: 'Domicile',
              to: 'Campus',
              time: '8 h 15',
              driverFirstName: 'Léa',
              seatsLeft: 2,
              status: UmRideStatus.inProgress,
              role: UmRideRole.passenger,
              live: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byType(UmLiveGradient), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      await tester.tap(find.textContaining('Domicile', findRichText: true));
      expect(taps, 1);
    });

    testWidgets('conducteur : « Tu reçois » devant le prix, lu en une phrase', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 400,
            child: UmRideCard(
              from: 'Domicile',
              to: 'Campus',
              time: '8 h 15',
              driverFirstName: '',
              seatsLeft: 1,
              priceCents: 480,
              priceLabel: 'Tu reçois',
              status: UmRideStatus.confirmed,
            ),
          ),
        ),
      );
      expect(find.textContaining('Tu reçois', findRichText: true), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tu reçois ${UmRideCard.formatPrice(480, 'fr')}'),
        findsOneWidget,
      );
    });

    test('formate les centimes sans flottant visible', () {
      expect(UmRideCard.formatPrice(5, 'fr'), '0,05 €');
      expect(UmRideCard.formatPrice(123456, 'fr'), '1 234,56 €');
    });
  });
}
