import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../demo_mode.dart';

/// Choix de la démo : compte prêt à l'emploi ou parcours d'inscription complet.
Future<void> showDemoSheet(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final choice = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final c = context.umColors;
      Widget option(IconData icon, String title, String help, bool value) => Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(UmRadius.md),
          onTap: () => Navigator.of(context).pop(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: UmSpace.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: UmSize.iconMd, color: c.brandStrong),
                ),
                const SizedBox(width: UmSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: UmText.button.copyWith(color: c.ink)),
                      Text(help, style: UmText.bodySm.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.demoSheetTitle, style: UmText.h2.copyWith(color: c.ink)),
              ),
              const SizedBox(height: UmSpace.s2),
              Text(l10n.demoSheetBody, style: UmText.body.copyWith(color: c.inkMuted)),
              const SizedBox(height: UmSpace.s4),
              option(Icons.person_outline_rounded, l10n.demoReady, l10n.demoReadyHelp, true),
              option(Icons.app_registration_rounded, l10n.demoSignup, l10n.demoSignupHelp, false),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null) return;
  final demo = ref.read(demoProvider.notifier);
  final backend = demo.start(withAccount: choice);
  if (choice) {
    // Session ouverte directement : le routeur emmène à l'accueil.
    await demo.storage.write(backend.signInDemo());
    ref.invalidate(sessionProvider);
    await ref.read(sessionProvider.future);
  } else {
    await ref.read(sessionProvider.future);
    await router.push(AppRoutes.signup);
  }
}
