import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/support.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../rides/data/nav_launcher.dart';
import '../../wallet/presentation/wallet_screen.dart';
import 'account_controller.dart';

/// Suppression du compte (RGPD) : ce qui est effacé, ce qui reste anonyme, puis le mot de passe.
/// Un portefeuille non vide bloque tout de suite, avant de demander le mot de passe.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref.read(accountActionsProvider).deleteAccount(_password.text);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountDone)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } on Object {
      // Erreur hors API (stockage local) : message générique, compte inchangé côté app.
      if (mounted) setState(() => _errorCode = 'unknown');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _writeToTeam() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(navLauncherProvider)
        .open(supportMailto(subject: l10n.deleteAccountMailSubject))
        .catchError((Object _) => false);
    // Pas d'application de mail : l'adresse reste affichée à l'écran.
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(l10n.noMailApp(supportEmail))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    // Lecture impossible : le serveur vérifie de toute façon à la suppression.
    final wallet = ref.watch(walletProvider).value;
    final leftCents = wallet == null ? 0 : wallet.balanceCents + wallet.heldCents;
    final blocked = leftCents > 0 || _errorCode == 'wallet_not_empty';

    Widget point(IconData icon, String lead, String text) => Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: UmSize.iconMd, color: c.brandStrong),
          ),
          const SizedBox(width: UmSpace.s3),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$lead ', style: UmText.button),
                  TextSpan(text: text),
                ],
              ),
              style: UmText.body.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );

    return UmPage(
      appBar: AppBar(),
      title: l10n.deleteAccountTitle,
      footer: [
        if (blocked)
          UmButton(label: l10n.deleteAccountWriteTeam, expand: true, onPressed: _writeToTeam)
        else
          UmButton(
            label: l10n.deleteAccountConfirm,
            expand: true,
            loading: _busy,
            onPressed: _password.text.isEmpty ? null : _delete,
          ),
        UmButton(
          label: l10n.deleteAccountCancel,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: () => context.pop(),
        ),
      ],
      children: [
        Text(l10n.deleteAccountIntro, style: UmText.button.copyWith(color: c.ink)),
        const SizedBox(height: UmSpace.s5),
        point(Icons.delete_outline_rounded, l10n.deleteAccountErasedLead, l10n.deleteAccountErased),
        point(Icons.inventory_2_outlined, l10n.deleteAccountKeptLead, l10n.deleteAccountKept),
        point(Icons.directions_car_outlined, l10n.deleteAccountRidesLead, l10n.deleteAccountRides),
        const SizedBox(height: UmSpace.s3),
        if (blocked)
          UmCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: UmSize.iconMd,
                    color: c.brandStrong,
                  ),
                ),
                const SizedBox(width: UmSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.deleteAccountWalletTitle, style: UmText.h3.copyWith(color: c.ink)),
                      const SizedBox(height: UmSpace.s2),
                      Text(
                        leftCents > 0
                            ? l10n.deleteAccountWalletLeft(
                                UmRideCard.formatPrice(leftCents, l10n.localeName),
                                supportEmail,
                              )
                            : l10n.errorWalletNotEmpty,
                        style: UmText.body.copyWith(color: c.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          UmField(
            label: l10n.deleteAccountPassword,
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            error: _errorCode == 'invalid_password' ? l10n.errorInvalidPassword : null,
          ),
          if (_errorCode != null && _errorCode != 'invalid_password') ...[
            const SizedBox(height: UmSpace.s4),
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
          ],
        ],
      ],
    );
  }
}
