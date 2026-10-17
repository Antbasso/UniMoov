import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/presentation/account_controller.dart';
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
        _Section(
          title: l10n.profileWallet,
          body: l10n.walletIntro,
          onEdit: () => context.push(AppRoutes.wallet),
        ),
        _Section(
          title: l10n.profileNotifications,
          body: l10n.profileNotificationsBody,
          onEdit: () => context.push(AppRoutes.notificationSettings),
        ),
        _Section(
          title: l10n.profileReliability,
          body: l10n.profileReliabilityBody,
          actionLabel: l10n.see,
          onEdit: () => context.push(AppRoutes.reliability),
        ),
        const _PausesSection(),
        const SizedBox(height: UmSpace.s4),
        const _DataSection(),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body, this.onEdit, this.actionLabel});

  final String title;
  final String body;
  final VoidCallback? onEdit;

  /// Libellé du bouton (« Modifier » par défaut).
  final String? actionLabel;

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
                  label: actionLabel ?? l10n.edit,
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

/// Droits RGPD : récupérer ses données, supprimer son compte (docs/rgpd.md).
class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _exporting = false;

  Future<void> _export(BuildContext buttonContext) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = true);
    try {
      await ref
          .read(accountActionsProvider)
          .exportData(subject: l10n.exportSubject, origin: origin);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(l10n, error.code))));
    } on Object {
      // Feuille de partage indisponible.
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UmCard(
      title: l10n.profileData,
      body: l10n.profileDataBody,
      child: Wrap(
        spacing: UmSpace.s3,
        runSpacing: UmSpace.s3,
        children: [
          Builder(
            builder: (buttonContext) => UmButton(
              label: l10n.exportAction,
              icon: Icons.download_rounded,
              variant: UmButtonVariant.secondary,
              loading: _exporting,
              onPressed: () => _export(buttonContext),
            ),
          ),
          UmButton(
            label: l10n.deleteAccountAction,
            variant: UmButtonVariant.ghost,
            onPressed: () => context.push(AppRoutes.deleteAccount),
          ),
        ],
      ),
    );
  }
}
