import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/wallet_api.dart';
import '../domain/wallet.dart';

/// Clé de la recharge en cours, gardée même si l'écran est quitté : une requête sans réponse
/// (réseau coupé) puis réessayée ne recharge qu'une fois. Renouvelée quand l'issue est connue.
class PendingTopupKey extends Notifier<String> {
  @override
  String build() {
    // Nouvelle session (autre compte possible) : nouvelle clé.
    ref.watch(sessionProvider);
    return newIdempotencyKey();
  }

  void rotate() => state = newIdempotencyKey();
}

final pendingTopupKeyProvider = NotifierProvider<PendingTopupKey, String>(PendingTopupKey.new);

/// Portefeuille (cahier §5) ; le parcours complet de recharge et de retrait arrive en M4b.
class WalletController extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() => ref.watch(walletApiProvider).wallet();

  Future<void> topup(int amountCents) async {
    final keys = ref.read(pendingTopupKeyProvider.notifier);
    try {
      final wallet = await ref
          .read(walletApiProvider)
          .topup(amountCents, ref.read(pendingTopupKeyProvider));
      keys.rotate();
      if (ref.mounted) state = AsyncData(wallet);
    } on ApiException catch (error) {
      // Refus définitif du prestataire : la prochaine tentative est une nouvelle recharge.
      if (error.code == 'topup_failed' || error.code == 'idempotency_conflict') keys.rotate();
      rethrow;
    }
  }
}

final walletProvider = AsyncNotifierProvider.autoDispose<WalletController, Wallet>(
  WalletController.new,
  retry: (retryCount, error) => null,
);

/// Recharge proposée : le minimum par défaut (`wallet.minTopupCents`, 10 €).
const topupCents = 1000;

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _busy = false;
  String? _errorCode;

  Future<void> _topup() async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final done = AppLocalizations.of(context).walletTopupDone;
    try {
      await ref.read(walletProvider.notifier).topup(topupCents);
      messenger.showSnackBar(SnackBar(content: Text(done)));
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
    final wallet = ref.watch(walletProvider);
    String euros(int cents) => UmRideCard.formatPrice(cents, l10n.localeName);

    return UmPage(
      appBar: AppBar(),
      title: l10n.walletTitle,
      intro: l10n.walletIntro,
      footer: [
        if (wallet.hasValue)
          UmButton(
            label: l10n.walletTopup(euros(topupCents)),
            expand: true,
            loading: _busy,
            onPressed: _topup,
          ),
      ],
      children: switch (wallet) {
        AsyncValue(:final value?) => [
          UmCard(
            child: Semantics(
              label: '${l10n.walletBalance} ${euros(value.balanceCents)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.walletBalance, style: UmText.label.copyWith(color: c.inkMuted)),
                  Text(euros(value.balanceCents), style: UmText.h1.copyWith(color: c.brandStrong)),
                  if (value.heldCents > 0)
                    Text(
                      l10n.walletHeld(euros(value.heldCents)),
                      style: UmText.bodySm.copyWith(color: c.inkMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: UmSpace.s3),
          Text(l10n.walletFake, style: UmText.caption.copyWith(color: c.inkMuted)),
          if (_errorCode != null) ...[
            const SizedBox(height: UmSpace.s3),
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
          ],
          const SizedBox(height: UmSpace.s5),
          Semantics(
            header: true,
            child: Text(l10n.walletHistory, style: UmText.h3.copyWith(color: c.ink)),
          ),
          const SizedBox(height: UmSpace.s3),
          if (value.history.isEmpty)
            Text(l10n.walletEmpty, style: UmText.body.copyWith(color: c.inkMuted))
          else
            for (final entry in value.history) _EntryRow(entry: entry),
        ],
        AsyncError(:final error) => [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(walletProvider),
          ),
        ],
        _ => [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        ],
      },
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final label = switch (entry.kind) {
      'topup' => l10n.walletKindTopup,
      'ride_charge' => l10n.walletKindRideCharge,
      'ride_credit' => l10n.walletKindRideCredit,
      'payout' => l10n.walletKindPayout,
      _ => l10n.walletKindRefund,
    };
    final amount = UmRideCard.formatPrice(entry.amountCents.abs(), l10n.localeName);
    // Sens écrit en toutes lettres (signe), jamais par la couleur seule.
    final signed = entry.amountCents < 0 ? '− $amount' : '+ $amount';
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: UmText.body.copyWith(color: c.ink)),
                Text(
                  DateFormat('d MMMM, H \'h\' mm', l10n.localeName).format(entry.at.toLocal()),
                  style: UmText.bodySm.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            signed,
            style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
