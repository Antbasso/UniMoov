import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/me.dart';
import 'me_controller.dart';
import 'profile_forms.dart';

/// Modification d'une partie du profil : même formulaire que l'onboarding, sans « Passer ».
class _EditScreen extends ConsumerWidget {
  const _EditScreen(this.builder);

  final Widget Function(Me me, ProfileFormFrame frame) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    if (me == null) return const SizedBox.shrink();
    // Routeur capturé ici : après l'enregistrement, le profil change et la page peut être
    // reconstruite ; le contexte d'origine ne sert plus à revenir en arrière.
    final router = GoRouter.of(context);
    return builder(
      me,
      ProfileFormFrame(
        appBar: AppBar(),
        primaryLabel: AppLocalizations.of(context).save,
        onDone: () async {
          if (router.canPop()) router.pop();
        },
      ),
    );
  }
}

class EditAddressScreen extends StatelessWidget {
  const EditAddressScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      _EditScreen((me, frame) => AddressForm(me: me, frame: frame));
}

class EditVehicleScreen extends StatelessWidget {
  const EditVehicleScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      _EditScreen((me, frame) => VehicleForm(me: me, frame: frame));
}

class EditRoleScreen extends StatelessWidget {
  const EditRoleScreen({super.key});

  @override
  Widget build(BuildContext context) => _EditScreen((me, frame) => RoleForm(me: me, frame: frame));
}
