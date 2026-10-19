import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../demo/presentation/demo_entry.dart';

/// Accueil avant connexion : promesse, bénéfices, inscription ou connexion.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;

    final actions = [
      UmButton(
        label: l10n.welcomeSignup,
        expand: true,
        onPressed: () => context.push(AppRoutes.signup),
      ),
      UmButton(
        label: l10n.welcomeLogin,
        variant: UmButtonVariant.ghost,
        expand: true,
        onPressed: () => context.push(AppRoutes.login),
      ),
      // Données fictives dans l'app, sans serveur : pour découvrir ou présenter Uni-Moov.
      UmButton(
        label: l10n.demoTry,
        icon: Icons.play_circle_outline_rounded,
        variant: UmButtonVariant.ghost,
        expand: true,
        onPressed: () => showDemoSheet(context, ref),
      ),
    ];

    // Tout tient sur un écran ; le défilement ne sert qu'avec un texte très agrandi.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: UmSpace.s6, vertical: UmSpace.s4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - UmSpace.s4 * 2),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Center(
                      child: UmLogo(
                        width: (constraints.maxHeight * 0.24).clamp(
                          UmSize.logoWidth / 2,
                          UmSize.logoHero,
                        ),
                      ),
                    ),
                    const SizedBox(height: UmSpace.s5),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.welcomeTitle,
                        textAlign: TextAlign.center,
                        style: UmText.h2.copyWith(color: c.ink),
                      ),
                    ),
                    const SizedBox(height: UmSpace.s2),
                    Text(
                      l10n.welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: UmText.bodySm.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: UmSpace.s5),
                    UmBenefitRow(
                      benefits: [
                        UmBenefit(icon: Icons.schedule_rounded, label: l10n.welcomeBenefitSchedule),
                        UmBenefit(icon: Icons.savings_outlined, label: l10n.welcomeBenefitPrice),
                        UmBenefit(
                          icon: Icons.handshake_outlined,
                          label: l10n.welcomeBenefitConfirm,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: UmSpace.s4),
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: UmSpace.s2),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo complet, sans plaque : « Moov » passe en clair sur fond sombre (logo_dark.png).
class UmLogo extends StatelessWidget {
  const UmLogo({super.key, this.width = UmSize.logoWidth});

  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png',
      width: width,
      // Proportions du fichier (1024 × 879) : place réservée avant le décodage de l'image.
      height: width * 879 / 1024,
      semanticLabel: AppLocalizations.of(context).logoLabel,
    );
  }
}

/// Logo compact (pastille et voiture), pour l'onglet Accueil.
class UmLogoCompact extends StatelessWidget {
  const UmLogoCompact({super.key, this.size = UmSize.iconMd});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/logo_compact.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
