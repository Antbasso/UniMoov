import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../profile/presentation/pause_sheet.dart';
import '../../proposals/presentation/week_section.dart';
import '../../wallet/presentation/wallet_screen.dart';

/// Écran principal connecté : bonjour et solde en tête, trajet en cours en premier, puis la
/// semaine. Mode découverte et pause restent visibles (cahier §12).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final me = ref.watch(meProvider).value;
    if (me == null) return const SizedBox.shrink();

    return UmPage(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.homeGreeting(me.firstName),
                  style: UmText.h1.copyWith(color: c.ink),
                ),
              ),
            ),
            const SizedBox(width: UmSpace.s3),
            const BalancePill(),
          ],
        ),
        const SizedBox(height: UmSpace.s3),
        // Lien aligné sur « Salut … » (pas la marge intérieure d'un bouton), zone tactile de 48 px.
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(UmRadius.sm),
              onTap: me.pausedToday
                  ? () => context.go(AppRoutes.profile)
                  : () => showPauseSheet(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: UmSize.tapTarget),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle_outline_rounded, color: c.brandStrong),
                    const SizedBox(width: UmSpace.s2),
                    Flexible(
                      child: Text(
                        me.pausedToday ? l10n.pausedToday : l10n.pauseAction,
                        style: UmText.button.copyWith(color: c.brandStrong),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (me.discoveryMode) ...[
          const SizedBox(height: UmSpace.s4),
          UmCard(
            title: l10n.discoveryTitle,
            body: l10n.discoveryBody,
            child: Align(
              alignment: Alignment.centerLeft,
              child: UmButton(
                label: l10n.discoveryAction,
                onPressed: () => context.push(AppRoutes.profileAddress),
              ),
            ),
          ),
        ],
        const SizedBox(height: UmSpace.s4),
        // Hors mode découverte : le matching a besoin de l'adresse (cahier §1).
        if (!me.discoveryMode) const WeekSection(),
      ],
    );
  }
}

/// Solde du portefeuille en haut à droite de l'accueil, avec une cagnotte ; ouvre le
/// portefeuille. Rien tant que le solde n'est pas connu (pas d'erreur bruyante ici).
class BalancePill extends ConsumerWidget {
  const BalancePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final balance = ref.watch(walletProvider).value?.balanceCents;
    if (balance == null) return const SizedBox.shrink();
    final amount = UmRideCard.formatPrice(balance, l10n.localeName);
    return Semantics(
      button: true,
      label: l10n.homeBalance(amount),
      excludeSemantics: true,
      child: Material(
        color: c.lavender,
        borderRadius: BorderRadius.circular(UmRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(UmRadius.pill),
          onTap: () => context.push(AppRoutes.wallet),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: UmSize.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined, size: UmSize.iconMd, color: c.brandStrong),
                  const SizedBox(width: UmSpace.s2),
                  Text(amount, style: UmText.button.copyWith(color: c.brandStrong)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
