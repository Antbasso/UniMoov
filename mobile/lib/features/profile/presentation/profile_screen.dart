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
import 'pause_format.dart';
import 'pause_sheet.dart';
import '../../../core/settings/appearance.dart';
import 'person_avatar.dart';
import 'photo_sheet.dart';
import '../../wallet/presentation/wallet_screen.dart';
import '../../achievements/presentation/achievements_controller.dart';
import '../../achievements/presentation/achievements_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final me = ref.watch(meProvider).value;
    if (me == null) return const SizedBox.shrink();

    final roleLabel = switch (me.roleMode) {
      RoleMode.auto => l10n.roleAuto,
      RoleMode.alwaysDriver => l10n.roleDriver,
      RoleMode.alwaysPassenger => l10n.rolePassenger,
    };
    final vehicle = me.vehicle;
    final balance = ref.watch(walletProvider).value?.balanceCents;

    return UmPage(
      footer: [
        UmButton(
          label: l10n.signOut,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ],
      children: [
        Row(
          children: [
            // Toucher la photo : en choisir une, la reprendre ou la retirer.
            Semantics(
              button: true,
              label: l10n.photoChange,
              excludeSemantics: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showPhotoSheet(context, ref, hasPhoto: me.photoUrl != null),
                child: Stack(
                  children: [
                    PersonAvatar(name: me.firstName, photoUrl: me.photoUrl, size: UmSize.avatarLg),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: UmSize.iconSm / 2 + UmSpace.s1,
                        backgroundColor: c.brandStrong,
                        child: Icon(
                          Icons.photo_camera_rounded,
                          size: UmSize.iconSm,
                          color: c.onBrand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: UmSpace.s4),
            Expanded(
              // Toucher son nom : son profil tel que les autres le voient.
              child: InkWell(
                borderRadius: BorderRadius.circular(UmRadius.sm),
                onTap: () => context.push(AppRoutes.person(me.id)),
                child: Semantics(
                  button: true,
                  hint: l10n.profileSeeMine,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                '${me.firstName} ${me.lastName}',
                                style: UmText.h2.copyWith(color: c.ink),
                              ),
                            ),
                            Text(
                              me.universityEmail,
                              style: UmText.bodySm.copyWith(color: c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: UmSpace.s5),
        // Niveau et points : toucher ouvre les badges et le classement.
        if (ref.watch(achievementsProvider).value case final achievements?) ...[
          LevelCard(achievements: achievements, onTap: () => context.push(AppRoutes.achievements)),
          const SizedBox(height: UmSpace.s5),
        ],
        _Group(
          title: l10n.sectionAbout,
          children: [
            _Row(
              icon: Icons.person_outline_rounded,
              title: l10n.aboutTitle,
              value: aboutSummary(l10n, me) ?? l10n.aboutEmpty,
              onTap: () => context.push(AppRoutes.profileAbout),
            ),
          ],
        ),
        const SizedBox(height: UmSpace.s5),
        _Group(
          title: l10n.sectionActivity,
          children: [
            _Row(
              icon: Icons.savings_outlined,
              title: l10n.profileWallet,
              value: balance == null ? null : UmRideCard.formatPrice(balance, l10n.localeName),
              strongValue: true,
              onTap: () => context.push(AppRoutes.wallet),
            ),
            _Row(
              icon: Icons.history_rounded,
              title: l10n.historyTitle,
              onTap: () => context.push(AppRoutes.history),
            ),
            _Row(
              icon: Icons.verified_outlined,
              title: l10n.profileReliability,
              onTap: () => context.push(AppRoutes.reliability),
            ),
            _Row(
              icon: Icons.emoji_events_outlined,
              title: l10n.achievementsTitle,
              onTap: () => context.push(AppRoutes.achievements),
            ),
          ],
        ),
        const SizedBox(height: UmSpace.s5),
        _Group(
          title: l10n.sectionTrips,
          children: [
            _Row(
              icon: Icons.home_outlined,
              title: l10n.profileAddress,
              value: me.home?.address ?? l10n.profileNoAddress,
              onTap: () => context.push(AppRoutes.profileAddress),
            ),
            _Row(
              icon: Icons.directions_car_outlined,
              title: l10n.profileVehicle,
              value: vehicle == null
                  ? l10n.profileNoVehicle
                  : [
                      ?[?vehicle.model, ?vehicle.color].join(' ').trim().nonEmpty,
                      l10n.profileVehicleSummary(
                        VehicleInput.formatConsumption(vehicle.consumptionLPer100km),
                        vehicle.defaultSeats,
                        vehicle.maxDetourMinutes,
                      ),
                    ].join(' · '),
              onTap: () => context.push(AppRoutes.profileVehicle),
            ),
            _Row(
              icon: Icons.swap_horiz_rounded,
              title: l10n.profileRole,
              value: roleLabel,
              onTap: () => context.push(AppRoutes.profileRole),
            ),
            _Row(
              icon: Icons.calendar_month_outlined,
              title: l10n.profileSchedule,
              onTap: () => context.push(AppRoutes.profileSchedule),
            ),
          ],
        ),
        const SizedBox(height: UmSpace.s5),
        const _PausesSection(),
        const SizedBox(height: UmSpace.s5),
        const _AppearanceGroup(),
        const SizedBox(height: UmSpace.s5),
        _Group(
          title: l10n.sectionAccount,
          children: [
            _Row(
              icon: Icons.notifications_none_rounded,
              title: l10n.profileNotifications,
              onTap: () => context.push(AppRoutes.notificationSettings),
            ),
            const _ExportRow(),
            _Row(
              icon: Icons.delete_outline_rounded,
              title: l10n.deleteAccountAction,
              onTap: () => context.push(AppRoutes.deleteAccount),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bloc de lignes du profil, sur une carte.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  /// Nom de la section, au-dessus de la carte.
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final card = Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.md),
        boxShadow: context.umShadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: UmSpace.s6 * 2, color: c.border),
              children[i],
            ],
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: UmSpace.s1, bottom: UmSpace.s2),
          child: Semantics(
            header: true,
            child: Text(title, style: UmText.label.copyWith(color: c.inkMuted)),
          ),
        ),
        card,
      ],
    );
  }
}

/// Ligne : icône, titre, valeur sur une ligne, chevron. Toute la ligne s'ouvre.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.strongValue = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? value;

  /// Valeur mise en avant à droite (solde) plutôt que sous le titre.
  final bool strongValue;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final value = this.value;
    return ListTile(
      minTileHeight: UmSize.tapTarget + UmSpace.s2,
      leading: Icon(icon, color: c.brandStrong),
      title: Text(
        title,
        style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
      ),
      subtitle: value == null || strongValue
          ? null
          : Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UmText.bodySm.copyWith(color: c.inkMuted),
            ),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null && strongValue)
                Text(value, style: UmText.h3.copyWith(color: c.brandStrong)),
              Icon(Icons.chevron_right_rounded, color: c.inkMuted),
            ],
          ),
      onTap: onTap,
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

    // Même gabarit que les autres lignes : icône, titre, bouton « + » aligné sur les chevrons.
    final rows = switch (pauses) {
      AsyncData(:final value) => [
        for (final pause in value)
          ListTile(
            minTileHeight: UmSize.tapTarget + UmSpace.s2,
            leading: const SizedBox(width: UmSize.iconMd),
            title: Text(
              describePause(
                startsOn: pause.startsOn,
                endsOn: pause.endsOn,
                repeat: pause.repeat,
                repeatUntil: pause.repeatUntil,
                l10n: l10n,
              ),
              style: UmText.bodySm.copyWith(color: c.ink),
            ),
            trailing: IconButton(
              tooltip: l10n.pauseDelete(formatPauseDate(pause.startsOn, l10n.localeName)),
              icon: Icon(Icons.delete_outline_rounded, color: c.brandStrong),
              onPressed: () => _remove(context, ref, pause.id),
            ),
          ),
      ],
      AsyncError(:final error) => [
        Padding(
          padding: const EdgeInsets.all(UmSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
              UmButton(
                label: l10n.retry,
                variant: UmButtonVariant.ghost,
                onPressed: () => ref.invalidate(pausesProvider),
              ),
            ],
          ),
        ),
      ],
      _ => [
        Semantics(
          label: l10n.loading,
          child: LinearProgressIndicator(color: c.brand, backgroundColor: c.lavender),
        ),
      ],
    };
    final none = pauses.value?.isEmpty ?? false;

    return _Group(
      title: l10n.sectionPauses,
      children: [
        _Row(
          icon: Icons.pause_circle_outline_rounded,
          title: l10n.profilePauses,
          value: none ? l10n.profileNoPauses : null,
          onTap: () => showPauseSheet(context),
          trailing: IconButton(
            tooltip: l10n.pauseAction,
            icon: Icon(Icons.add_rounded, color: c.brandStrong),
            onPressed: () => showPauseSheet(context),
          ),
        ),
        ...rows,
      ],
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

/// Droit d'accès (docs/rgpd.md) : récupérer ses données en un fichier.
class _ExportRow extends ConsumerStatefulWidget {
  const _ExportRow();

  @override
  ConsumerState<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends ConsumerState<_ExportRow> {
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
    final c = context.umColors;
    return Builder(
      builder: (rowContext) => _Row(
        icon: Icons.download_rounded,
        title: l10n.exportAction,
        onTap: _exporting ? null : () => _export(rowContext),
        trailing: _exporting
            ? SizedBox.square(
                dimension: UmSize.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.brand),
              )
            : null,
      ),
    );
  }
}

/// « BUT Informatique · 21 ans · Escalade, Jazz », ou null si rien n'est renseigné.
String? aboutSummary(AppLocalizations l10n, Me me) {
  final age = me.birthYear == null ? null : DateTime.now().year - me.birthYear!;
  final parts = [
    ?me.studyProgram,
    if (age != null) l10n.ageYears(age),
    if (me.interests.isNotEmpty) me.interests.join(', '),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Apparence : thème (automatique, clair, sombre) et animations réduites, gardés sur le
/// téléphone.
class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    String label(ThemeMode mode) => switch (mode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };
    return _Group(
      title: l10n.sectionAppearance,
      children: [
        _Row(
          icon: Icons.dark_mode_outlined,
          title: l10n.themeTitle,
          value: label(appearance.themeMode),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (sheet) => SafeArea(
              child: RadioGroup<ThemeMode>(
                groupValue: appearance.themeMode,
                onChanged: (mode) {
                  if (mode != null) controller.setThemeMode(mode);
                  Navigator.of(sheet).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in ThemeMode.values)
                      RadioListTile<ThemeMode>(value: mode, title: Text(label(mode))),
                  ],
                ),
              ),
            ),
          ),
        ),
        SwitchListTile(
          secondary: Icon(Icons.motion_photos_off_outlined, color: c.brandStrong),
          title: Text(
            l10n.reduceMotion,
            style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
          ),
          value: appearance.reduceMotion,
          onChanged: controller.setReduceMotion,
        ),
      ],
    );
  }
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
