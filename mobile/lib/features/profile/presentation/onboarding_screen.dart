import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/me.dart';
import 'me_controller.dart';
import '../../schedule/presentation/schedule_step.dart';
import 'profile_forms.dart';

/// Onboarding par étapes, chacune avec « Passer pour l'instant ». L'étape affichée est
/// celle que le serveur indique (`nextStep`) : quitter puis revenir reprend au même endroit.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).value;
    final step = me?.nextStep;
    // Le routeur quitte cet écran dès que l'onboarding est terminé.
    if (me == null || step == null) return const SizedBox.shrink();

    final controller = ref.read(meProvider.notifier);
    final frame = ProfileFormFrame(
      overline: l10n.onboardingProgress(step.index + 1, OnboardingStep.values.length),
      primaryLabel: l10n.continueAction,
      onDone: () => controller.setStep(step, StepStatus.done),
      onSkip: () => controller.setStep(step, StepStatus.skipped),
    );

    // Une clé par étape : chaque formulaire repart de zéro.
    return switch (step) {
      OnboardingStep.profile => AddressForm(key: ValueKey(step), me: me, frame: frame),
      OnboardingStep.vehicle => VehicleForm(key: ValueKey(step), me: me, frame: frame),
      OnboardingStep.preferences => RoleForm(key: ValueKey(step), me: me, frame: frame),
      OnboardingStep.calendar => ScheduleStep(key: ValueKey(step), frame: frame),
    };
  }
}
