import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wallet.dart';
import 'wallet_screen.dart';

/// Minimum de retrait par défaut (`wallet.minPayoutCents`) ; le serveur fait foi.
const minPayoutCents = 1000;

/// Retrait du solde vers un compte bancaire (cahier §5) : montant, IBAN et titulaire. L'IBAN
/// n'est pas gardé sur le téléphone ; le serveur n'en garde que les 4 derniers caractères.
class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  final _amount = TextEditingController();
  final _iban = TextEditingController();
  final _holder = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    for (final c in [_amount, _iban, _holder]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _iban.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final cents = parseEurosToCents(_amount.text);
    if (cents == null || _holder.text.trim().length < 2) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref
          .read(walletProvider.notifier)
          .payout(
            PayoutRequest(
              amountCents: cents,
              iban: _iban.text.replaceAll(' ', '').toUpperCase(),
              holderName: _holder.text.trim(),
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.walletPayoutDone)));
      if (router.canPop()) router.pop();
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
    String euros(int cents) => UmRideCard.formatPrice(cents, l10n.localeName);
    final balance = ref.watch(walletProvider).value?.balanceCents;
    final cents = parseEurosToCents(_amount.text);
    final amountError = _submitted && cents == null
        ? l10n.walletPayoutAmountInvalid
        : switch (_errorCode) {
            'payout_too_small' => l10n.errorPayoutTooSmall,
            'insufficient_funds' => l10n.errorInsufficientFunds,
            _ => null,
          };
    final fieldCodes = {'payout_too_small', 'insufficient_funds', 'iban_invalid'};
    final ready = _amount.text.isNotEmpty && _iban.text.isNotEmpty && _holder.text.isNotEmpty;

    return UmPage(
      appBar: AppBar(),
      title: l10n.walletPayoutTitle,
      intro: l10n.walletPayoutIntro,
      footer: [
        UmButton(
          label: cents == null ? l10n.walletPayout : l10n.walletPayoutSubmit(euros(cents)),
          expand: true,
          loading: _busy,
          onPressed: ready && !_busy ? _submit : null,
        ),
      ],
      children: [
        if (balance != null) ...[
          Text(
            '${l10n.walletBalance} : ${euros(balance)}',
            style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: UmSpace.s4),
        ],
        UmField(
          label: l10n.walletPayoutAmount,
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          help: l10n.walletPayoutRule(euros(minPayoutCents)),
          error: amountError,
        ),
        const SizedBox(height: UmSpace.s4),
        UmField(
          label: l10n.walletPayoutIban,
          controller: _iban,
          placeholder: 'FR76 …',
          maxLength: 42,
          counterFrom: 38,
          error: _errorCode == 'iban_invalid' ? l10n.errorIbanInvalid : null,
        ),
        const SizedBox(height: UmSpace.s4),
        UmField(
          label: l10n.walletPayoutHolder,
          controller: _holder,
          autofillHints: const [AutofillHints.name],
          maxLength: 70,
          counterFrom: 60,
          error: _submitted && _holder.text.trim().length < 2
              ? l10n.walletPayoutHolderInvalid
              : null,
        ),
        if (_errorCode != null && !fieldCodes.contains(_errorCode)) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}
