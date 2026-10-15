import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/profile_forms.dart';
import 'schedule_controller.dart';
import 'schedule_forms.dart';

/// Emploi du temps depuis le profil : état, mise à jour, déconnexion, ou saisie.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  bool _busy = false;
  String? _errorCode;

  Future<void> _run(Future<void> Function() action, String? done) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final schedule = ref.watch(scheduleProvider);
    final controller = ref.read(scheduleProvider.notifier);

    return UmPage(
      appBar: AppBar(),
      title: l10n.profileSchedule,
      children: switch (schedule) {
        AsyncData(:final value) => [
          if (value.connection case final connection?) ...[
            Text(
              l10n.scheduleConnected(
                DateFormat.yMMMd(l10n.localeName)
                    .format((connection.lastSyncedAt ?? connection.consentedAt).toLocal()),
              ),
              style: UmText.body.copyWith(color: c.ink),
            ),
            if (connection.lastError != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(l10n.scheduleSyncError),
            ],
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: l10n.scheduleSync,
              icon: Icons.sync_rounded,
              variant: UmButtonVariant.secondary,
              loading: _busy,
              onPressed: () => _run(controller.sync, l10n.scheduleSynced),
            ),
            const SizedBox(height: UmSpace.s2),
            UmButton(
              label: l10n.scheduleDisconnect,
              variant: UmButtonVariant.ghost,
              onPressed: _busy ? null : () => _run(controller.disconnect, null),
            ),
          ] else ...[
            Text(
              value.manualDays.isEmpty
                  ? l10n.scheduleNone
                  : l10n.scheduleManualSummary(value.manualDays.length),
              style: UmText.body.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: l10n.calendarChooseIcs,
              icon: Icons.link_rounded,
              variant: UmButtonVariant.secondary,
              expand: true,
              onPressed: () => context.push(AppRoutes.profileScheduleIcs),
            ),
            const SizedBox(height: UmSpace.s3),
            UmButton(
              label: l10n.calendarChooseManual,
              icon: Icons.edit_calendar_outlined,
              variant: UmButtonVariant.secondary,
              expand: true,
              onPressed: () => context.push(AppRoutes.profileScheduleManual),
            ),
          ],
          if (_errorCode != null) ...[
            const SizedBox(height: UmSpace.s4),
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
          ],
        ],
        AsyncError(:final error) => [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(scheduleProvider),
          ),
        ],
        _ => [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        ],
      },
    );
  }
}

ProfileFormFrame _editFrame(BuildContext context) {
  final router = GoRouter.of(context);
  return ProfileFormFrame(
    appBar: AppBar(),
    primaryLabel: AppLocalizations.of(context).save,
    onDone: () async {
      if (router.canPop()) router.pop();
    },
  );
}

class EditIcsScreen extends StatelessWidget {
  const EditIcsScreen({super.key});

  @override
  Widget build(BuildContext context) => IcsForm(frame: _editFrame(context));
}

class EditManualScheduleScreen extends ConsumerWidget {
  const EditManualScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(scheduleProvider);
    if (schedule.value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ManualScheduleForm(initial: schedule.value!.manualDays, frame: _editFrame(context));
  }
}
