import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/api_health.dart';
import 'api_health_provider.dart';

/// Écran d'accueil du pilote (jalon M0).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UmSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Logo()),
              const SizedBox(height: UmSpace.s6),
              Semantics(
                header: true,
                child: Text(l10n.homeTitle, style: UmText.h1.copyWith(color: c.ink)),
              ),
              const SizedBox(height: UmSpace.s3),
              Text(l10n.homeSubtitle, style: UmText.h3.copyWith(color: c.brandStrong)),
              const SizedBox(height: UmSpace.s6),
              UmBenefitRow(
                benefits: [
                  UmBenefit(icon: Icons.schedule_rounded, label: l10n.homeBenefitSchedule),
                  UmBenefit(icon: Icons.savings_outlined, label: l10n.homeBenefitPrice),
                  UmBenefit(icon: Icons.handshake_outlined, label: l10n.homeBenefitConfirm),
                ],
              ),
              const SizedBox(height: UmSpace.s6),
              Center(child: UmNote(text: l10n.homeNote)),
              const SizedBox(height: UmSpace.s6),
              UmButton(
                label: l10n.homeStart,
                expand: true,
                onPressed: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l10n.homeStartSoon))),
              ),
              const SizedBox(height: UmSpace.s5),
              const Center(child: _ApiStatus()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    // Le logo a un fond blanc opaque : jamais directement sur un fond sombre (logo.md).
    // On le pose sur la plaque claire `surface-raised` du thème clair dans les deux thèmes.
    return Container(
      padding: const EdgeInsets.all(UmSpace.s3),
      decoration: BoxDecoration(
        color: UmColorTokens.light.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.lg),
      ),
      child: Image.asset(
        'assets/images/logo.png',
        width: UmSize.logoWidth,
        semanticLabel: AppLocalizations.of(context).logoLabel,
      ),
    );
  }
}

class _ApiStatus extends ConsumerWidget {
  const _ApiStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final health = ref.watch(apiHealthProvider);

    return switch (health) {
      AsyncData(value: ApiHealth.ok) => UmChip(
        label: l10n.apiStatusOk,
        icon: Icons.check_circle_outline_rounded,
        tone: UmChipTone.success,
      ),
      AsyncData(value: ApiHealth.degraded) => UmChip(
        label: l10n.apiStatusDegraded,
        icon: Icons.warning_amber_rounded,
        tone: UmChipTone.danger,
      ),
      AsyncError() => Column(
        children: [
          UmChip(
            label: l10n.apiStatusError,
            icon: Icons.error_outline_rounded,
            tone: UmChipTone.danger,
          ),
          const SizedBox(height: UmSpace.s2),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(apiHealthProvider),
          ),
        ],
      ),
      _ => UmChip(label: l10n.apiStatusLoading, icon: Icons.sync_rounded),
    };
  }
}
