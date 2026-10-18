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

/// Écran principal connecté : mode découverte, pause visible (cahier §12), semaine à venir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).value;
    if (me == null) return const SizedBox.shrink();

    return UmPage(
      title: l10n.homeGreeting(me.firstName),
      children: [
        Wrap(
          spacing: UmSpace.s3,
          runSpacing: UmSpace.s3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (me.pausedToday)
              UmChip(label: l10n.pausedToday, icon: Icons.pause_circle_outline_rounded),
            UmButton(
              label: me.pausedToday ? l10n.pauseManage : l10n.pauseAction,
              icon: Icons.pause_circle_outline_rounded,
              variant: UmButtonVariant.secondary,
              onPressed: () =>
                  me.pausedToday ? context.go(AppRoutes.profile) : showPauseSheet(context),
            ),
          ],
        ),
        if (me.discoveryMode) ...[
          const SizedBox(height: UmSpace.s5),
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
        const SizedBox(height: UmSpace.s6),
        // Hors mode découverte : le matching a besoin de l'adresse (cahier §1).
        if (!me.discoveryMode) const WeekSection(),
      ],
    );
  }
}
