import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Accueil avant connexion : promesse, bénéfices, inscription ou connexion.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;

    return UmPage(
      footer: [
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
      ],
      children: [
        const Center(child: UmLogo()),
        const SizedBox(height: UmSpace.s6),
        Semantics(
          header: true,
          child: Text(l10n.welcomeTitle, style: UmText.h1.copyWith(color: c.ink)),
        ),
        const SizedBox(height: UmSpace.s3),
        Text(l10n.welcomeSubtitle, style: UmText.h3.copyWith(color: c.brandStrong)),
        const SizedBox(height: UmSpace.s6),
        UmBenefitRow(
          benefits: [
            UmBenefit(icon: Icons.schedule_rounded, label: l10n.welcomeBenefitSchedule),
            UmBenefit(icon: Icons.savings_outlined, label: l10n.welcomeBenefitPrice),
            UmBenefit(icon: Icons.handshake_outlined, label: l10n.welcomeBenefitConfirm),
          ],
        ),
        const SizedBox(height: UmSpace.s6),
        Center(child: UmNote(text: l10n.welcomeNote)),
      ],
    );
  }
}

/// Logo complet. Fond blanc opaque : jamais directement sur un fond sombre (logo.md),
/// donc posé sur la plaque claire `surface-raised` du thème clair dans les deux thèmes.
class UmLogo extends StatelessWidget {
  const UmLogo({super.key, this.width = UmSize.logoWidth});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UmSpace.s3),
      decoration: BoxDecoration(
        color: UmColorTokens.light.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.lg),
      ),
      child: Image.asset(
        'assets/images/logo.png',
        width: width,
        semanticLabel: AppLocalizations.of(context).logoLabel,
      ),
    );
  }
}
