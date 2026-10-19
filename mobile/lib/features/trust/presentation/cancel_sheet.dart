import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../proposals/presentation/proposals_controller.dart';
import '../../rides/presentation/active_ride.dart';
import '../data/trust_api.dart';
import '../domain/trust.dart';
import 'trust_info.dart';

final _cancellationProvider = FutureProvider.autoDispose.family<CancellationInfo, String>(
  (ref, rideId) => ref.watch(trustApiProvider).cancellation(rideId),
  retry: (retryCount, error) => null,
);

/// Annuler après acceptation (cahier §8) : la pénalité est annoncée avant de confirmer.
/// Renvoie le message de confirmation si l'annulation est faite, `null` sinon.
Future<String?> showCancelSheet(BuildContext context, String rideId) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CancelSheet(rideId: rideId),
    );

class CancelSheet extends ConsumerStatefulWidget {
  const CancelSheet({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<CancelSheet> {
  bool _busy = false;
  String? _errorCode;

  Future<void> _confirm(CancellationInfo shown) async {
    final l10n = AppLocalizations.of(context);
    final done = shown.isDriver ? l10n.cancelDone : l10n.cancelDonePassenger;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      final applied = await ref.read(trustApiProvider).cancel(widget.rideId);
      // Le trajet quitte l'accueil, le bandeau « en cours » et les conversations.
      ref
        ..invalidate(weekProposalsProvider)
        ..invalidate(activeRideProvider)
        ..invalidate(conversationsProvider);
      // Seuil franchi pendant que la feuille était ouverte : on dit le palier vraiment appliqué.
      if (mounted) {
        Navigator.of(context)
            .pop(applied == shown.tier ? done : '$done ${tierText(l10n, applied)}');
      }
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
    final info = ref.watch(_cancellationProvider(widget.rideId));
    final error =
        _errorCode ?? (info.error is ApiException ? (info.error! as ApiException).code : null);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                info.value?.isDriver ?? true
                    ? l10n.cancelSheetTitle
                    : l10n.cancelSheetTitlePassenger,
                style: UmText.h2.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: UmSpace.s3),
            switch (info) {
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrustInfo(icon: Icons.trending_down_rounded, text: tierText(l10n, value.tier)),
                  const SizedBox(height: UmSpace.s3),
                  Text(
                    value.isDriver ? l10n.cancelDriverEffect : l10n.cancelPassengerEffect,
                    style: UmText.bodySm.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
              AsyncError() => const SizedBox.shrink(),
              _ => Semantics(
                label: l10n.loading,
                child: LinearProgressIndicator(color: c.brand),
              ),
            },
            if (error != null || info.hasError) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, error)),
            ],
            if (info.hasError && !info.isLoading)
              UmButton(
                label: l10n.retry,
                variant: UmButtonVariant.ghost,
                onPressed: () => ref.invalidate(_cancellationProvider(widget.rideId)),
              ),
            const SizedBox(height: UmSpace.s5),
            UmButton(
              label: info.value?.isDriver ?? true ? l10n.cancelRide : l10n.cancelMyPlace,
              expand: true,
              loading: _busy,
              onPressed: info.value != null && !_busy ? () => _confirm(info.value!) : null,
            ),
            UmButton(
              label: l10n.cancelKeep,
              variant: UmButtonVariant.ghost,
              expand: true,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

String tierText(AppLocalizations l10n, CancelTier tier) => switch (tier) {
  CancelTier.early => l10n.cancelTierEarly,
  CancelTier.medium => l10n.cancelTierMedium,
  CancelTier.late => l10n.cancelTierLate,
};
