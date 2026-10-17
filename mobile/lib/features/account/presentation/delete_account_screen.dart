import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import 'account_controller.dart';

/// Suppression du compte (RGPD) : ce qui est effacé, ce qui reste anonyme, puis le mot de passe.
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: UmSize.iconMd, color: c.brandStrong),
          ),
          const SizedBox(width: UmSpace.s3),
          Expanded(
            child: Text(text, style: UmText.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );

    return UmPage(
      appBar: AppBar(),
      title: l10n.deleteAccountTitle,
      intro: l10n.deleteAccountIntro,
      footer: [
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
        point(Icons.delete_outline_rounded, l10n.deleteAccountErased),
        point(Icons.inventory_2_outlined, l10n.deleteAccountKept),
        point(Icons.directions_car_outlined, l10n.deleteAccountRides),
        point(Icons.account_balance_wallet_outlined, l10n.deleteAccountWallet),
        const SizedBox(height: UmSpace.s3),
        UmField(
          label: l10n.deleteAccountPassword,
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
        ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}
