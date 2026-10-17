import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notifications_api.dart';
import '../data/push_service.dart';
import 'push_controller.dart';

/// Préférences fines (cahier §11) : par exemple couper le chat en gardant les rappels.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  String? _errorCode;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Retour des réglages du téléphone : l'état de l'autorisation est relu.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(pushBlockedProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _save(NotificationPreferences prefs) async {
    setState(() => _errorCode = null);
    try {
      await ref.read(notificationPreferencesProvider.notifier).save(prefs);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final prefs = ref.watch(notificationPreferencesProvider);
    final blocked = ref.watch(pushBlockedProvider).value ?? false;

    Widget toggle(
      String title,
      String subtitle,
      bool value,
      NotificationPreferences Function(bool) change,
    ) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(title, style: UmText.body.copyWith(color: c.ink)),
      subtitle: Text(subtitle, style: UmText.bodySm.copyWith(color: c.inkMuted)),
      onChanged: (v) => _save(change(v)),
    );

    return UmPage(
      appBar: AppBar(),
      title: l10n.notificationsTitle,
      intro: l10n.notificationsIntro,
      children: [
        if (blocked) ...[
          UmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: UmSize.iconMd,
                        color: c.brandStrong,
                      ),
                    ),
                    const SizedBox(width: UmSpace.s3),
                    Expanded(
                      child: Text(
                        l10n.notificationsBlockedTitle,
                        style: UmText.h3.copyWith(color: c.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UmSpace.s2),
                Text(l10n.notificationsBlockedBody, style: UmText.body.copyWith(color: c.ink)),
                const SizedBox(height: UmSpace.s4),
                UmButton(
                  label: l10n.notificationsOpenSettings,
                  onPressed: () => ref.read(pushServiceProvider).openSettings(),
                ),
              ],
            ),
          ),
          const SizedBox(height: UmSpace.s4),
        ],
        switch (prefs) {
          AsyncValue(:final value?) => Column(
            children: [
              toggle(
                l10n.notificationsRideReminder,
                l10n.notificationsRideReminderHelp,
                value.rideReminder,
                (v) => NotificationPreferences(
                  match: value.match,
                  rideUpdate: value.rideUpdate,
                  rideReminder: v,
                  chat: value.chat,
                ),
              ),
              toggle(
                l10n.notificationsRideUpdate,
                l10n.notificationsRideUpdateHelp,
                value.rideUpdate,
                (v) => NotificationPreferences(
                  match: value.match,
                  rideUpdate: v,
                  rideReminder: value.rideReminder,
                  chat: value.chat,
                ),
              ),
              toggle(
                l10n.notificationsMatch,
                l10n.notificationsMatchHelp,
                value.match,
                (v) => NotificationPreferences(
                  match: v,
                  rideUpdate: value.rideUpdate,
                  rideReminder: value.rideReminder,
                  chat: value.chat,
                ),
              ),
              toggle(
                l10n.notificationsChat,
                l10n.notificationsChatHelp,
                value.chat,
                (v) => NotificationPreferences(
                  match: value.match,
                  rideUpdate: value.rideUpdate,
                  rideReminder: value.rideReminder,
                  chat: v,
                ),
              ),
            ],
          ),
          AsyncError(:final error) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
              UmButton(
                label: l10n.retry,
                variant: UmButtonVariant.ghost,
                onPressed: () => ref.invalidate(notificationPreferencesProvider),
              ),
            ],
          ),
          _ => Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        },
        if (blocked && prefs.hasValue) ...[
          const SizedBox(height: UmSpace.s2),
          Text(l10n.notificationsBlockedHelp, style: UmText.bodySm.copyWith(color: c.inkMuted)),
        ],
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}
