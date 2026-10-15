import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_forms.dart';
import 'schedule_controller.dart';
import 'schedule_forms.dart';

enum _Mode { choose, ics, manual }

/// Étape « emploi du temps » de l'onboarding : lien ICS, saisie manuelle ou plus tard.
class ScheduleStep extends ConsumerStatefulWidget {
  const ScheduleStep({super.key, required this.frame});

  /// `onDone` : étape faite ; `onSkip` : configurer plus tard.
  final ProfileFormFrame frame;

  @override
  ConsumerState<ScheduleStep> createState() => _ScheduleStepState();
}

class _ScheduleStepState extends ConsumerState<ScheduleStep> {
  _Mode _mode = _Mode.choose;
  bool _busy = false;

  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      await widget.frame.onSkip!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sub = ProfileFormFrame(
      overline: widget.frame.overline,
      primaryLabel: widget.frame.primaryLabel,
      onDone: widget.frame.onDone,
      appBar: AppBar(leading: BackButton(onPressed: () => setState(() => _mode = _Mode.choose))),
    );
    return switch (_mode) {
      _Mode.ics => IcsForm(frame: sub),
      _Mode.manual => ManualScheduleForm(
        initial: ref.watch(scheduleProvider).value?.manualDays ?? const [],
        frame: sub,
      ),
      _Mode.choose => UmPage(
        overline: widget.frame.overline,
        title: l10n.calendarTitle,
        intro: l10n.calendarBody,
        footer: [
          UmButton(
            label: l10n.skipForNow,
            variant: UmButtonVariant.ghost,
            expand: true,
            loading: _busy,
            onPressed: _skip,
          ),
        ],
        children: [
          UmButton(
            label: l10n.calendarChooseIcs,
            icon: Icons.link_rounded,
            variant: UmButtonVariant.secondary,
            expand: true,
            onPressed: () => setState(() => _mode = _Mode.ics),
          ),
          const SizedBox(height: UmSpace.s3),
          UmButton(
            label: l10n.calendarChooseManual,
            icon: Icons.edit_calendar_outlined,
            variant: UmButtonVariant.secondary,
            expand: true,
            onPressed: () => setState(() => _mode = _Mode.manual),
          ),
        ],
      ),
    };
  }
}
