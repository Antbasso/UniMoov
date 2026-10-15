import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/me.dart';
import '../domain/vehicle_input.dart';
import 'me_controller.dart';
import 'pause_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).value;
    if (me == null) return const SizedBox.shrink();

    final roleLabel = switch (me.roleMode) {
      RoleMode.auto => l10n.roleAuto,
      RoleMode.alwaysDriver => l10n.roleDriver,
      RoleMode.alwaysPassenger => l10n.rolePassenger,
    };
    final vehicle = me.vehicle;

    return UmPage(
      appBar: AppBar(),
      title: l10n.profileTitle,
      footer: [
        UmButton(
          label: l10n.signOut,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ],
      children: [
        _Section(
          title: l10n.profileIdentity,
          body: '${me.firstName} ${me.lastName}\n${me.universityEmail}',
        ),
        _Section(
          title: l10n.profileAddress,
          body: me.home?.address ?? l10n.profileNoAddress,
          onEdit: () => context.push(AppRoutes.profileAddress),
        ),
        _Section(
          title: l10n.profileVehicle,
          body: vehicle == null
              ? l10n.profileNoVehicle
              : l10n.profileVehicleSummary(
                  VehicleInput.formatConsumption(vehicle.consumptionLPer100km),
                  vehicle.defaultSeats,
                  vehicle.maxDetourMinutes,
                ),
          onEdit: () => context.push(AppRoutes.profileVehicle),
        ),
        _Section(
          title: l10n.profileRole,
          body: roleLabel,
          onEdit: () => context.push(AppRoutes.profileRole),
        ),
        _Section(
          title: l10n.profileSchedule,
          body: l10n.calendarBody,
          onEdit: () => context.push(AppRoutes.profileSchedule),
        ),
        const _PausesSection(),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body, this.onEdit});

  final String title;
  final String body;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s4),
      child: UmCard(
        title: title,
        body: body,
        child: onEdit == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: UmButton(
                  label: l10n.edit,
                  variant: UmButtonVariant.secondary,
                  onPressed: onEdit,
                ),
              ),
      ),
    );
  }
}

class _PausesSection extends ConsumerWidget {
  const _PausesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final pauses = ref.watch(pausesProvider);

    final content = switch (pauses) {
      AsyncData(:final value) when value.isEmpty => [
        Text(l10n.profileNoPauses, style: UmText.bodySm.copyWith(color: c.inkMuted)),
      ],
      AsyncData(:final value) => [
        for (final pause in value)
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    l10n.pauseRange(
                      formatPauseDate(pause.startsOn, l10n.localeName),
                      formatPauseDate(pause.endsOn, l10n.localeName),
                    ),
                    if (pause.everyWeeks != null) l10n.pauseAlternating(pause.everyWeeks!),
                  ].join(', '),
                  style: UmText.bodySm.copyWith(color: c.ink),
                ),
              ),
              IconButton(
                tooltip: l10n.pauseDelete(formatPauseDate(pause.startsOn, l10n.localeName)),
                icon: Icon(Icons.delete_outline_rounded, color: c.brandStrong),
                onPressed: () => _remove(context, ref, pause.id),
              ),
            ],
          ),
      ],
      AsyncError(:final error) => [
        UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
        UmButton(
          label: l10n.retry,
          variant: UmButtonVariant.ghost,
          onPressed: () => ref.invalidate(pausesProvider),
        ),
      ],
      _ => [
        Semantics(
          label: l10n.loading,
          child: LinearProgressIndicator(color: c.brand, backgroundColor: c.lavender),
        ),
      ],
    };

    return UmCard(
      title: l10n.profilePauses,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...content,
          const SizedBox(height: UmSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: UmButton(
              label: l10n.pauseAction,
              icon: Icons.pause_circle_outline_rounded,
              variant: UmButtonVariant.secondary,
              onPressed: () => showPauseSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(pausesProvider.notifier).remove(id);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(AppLocalizations.of(context), error.code))),
      );
    }
  }
}
