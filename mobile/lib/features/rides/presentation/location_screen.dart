import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Explication avant la demande système (AGENTS.md « Cartes, temps réel ») : pourquoi, à qui,
/// combien de temps. Renvoie `true` si la permission est accordée.
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen> {
  bool _busy = false;
  bool _deniedForever = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final access = await ref.read(locationServiceProvider).request();
    if (!mounted) return;
    setState(() => _busy = false);
    if (access == LocationAccess.granted) {
      router.pop(true);
    } else {
      setState(() => _deniedForever = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return UmPage(
      appBar: AppBar(),
      title: l10n.locationTitle,
      intro: l10n.locationBody,
      footer: [
        if (_deniedForever)
          UmButton(
            label: l10n.locationOpenSettings,
            expand: true,
            onPressed: () => ref.read(locationServiceProvider).openSettings(),
          )
        else
          UmButton(label: l10n.locationAllow, expand: true, loading: _busy, onPressed: _allow),
        UmButton(
          label: l10n.locationLater,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: () => context.pop(false),
        ),
      ],
      children: [
        Text(l10n.locationBackground, style: UmText.body.copyWith(color: c.ink)),
        if (_deniedForever) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(l10n.locationDenied),
        ],
      ],
    );
  }
}
