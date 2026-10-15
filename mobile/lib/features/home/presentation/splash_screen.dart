import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../profile/presentation/me_controller.dart';
import 'welcome_screen.dart';

/// Attente au lancement (session et profil) ; gère aussi l'échec du chargement du profil.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final me = ref.watch(meProvider);

    if (me case AsyncError(:final error)) {
      final code = error is ApiException ? error.code : null;
      return UmPage(
        title: l10n.splashError,
        footer: [
          UmButton(label: l10n.retry, expand: true, onPressed: () => ref.invalidate(meProvider)),
          UmButton(
            label: l10n.signOut,
            variant: UmButtonVariant.ghost,
            expand: true,
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
        children: [UmErrorText(apiErrorMessage(l10n, code))],
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UmLogo(),
            const SizedBox(height: UmSpace.s6),
            Semantics(
              label: l10n.loading,
              child: CircularProgressIndicator(color: c.brand, strokeWidth: UmSize.iconStroke),
            ),
          ],
        ),
      ),
    );
  }
}
