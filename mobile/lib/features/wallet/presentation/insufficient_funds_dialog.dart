import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../../l10n/app_localizations.dart';

/// Solde insuffisant pour réserver un trajet (le prix maximal doit être couvert, cahier §5) :
/// explication et accès direct à la recharge.
Future<void> showInsufficientFunds(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final topup = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.insufficientFundsTitle),
      content: Text(l10n.insufficientFundsBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.insufficientFundsLater),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.insufficientFundsTopup),
        ),
      ],
    ),
  );
  if (topup ?? false) await router.push(AppRoutes.wallet);
}
