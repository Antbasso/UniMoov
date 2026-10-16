import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trust.dart';
import 'trust_controller.dart';
import 'trust_info.dart';

/// Litige sur un trajet (cahier §10) : niveau 1 tranché sur les horodatages du serveur,
/// sinon ou en cas de désaccord, transmis à l'équipe (réponse par mail).
class DisputeScreen extends ConsumerStatefulWidget {
  const DisputeScreen({super.key, required this.rideId, this.reason});

  final String rideId;
  final DisputeReason? reason;

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  late DisputeReason? _reason = widget.reason;
  final _message = TextEditingController();
  bool _busy = false;
  String? _errorCode;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String? get _text => _message.text.trim().isEmpty ? null : _message.text.trim();

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    await _run(() async {
      await ref.read(disputesProvider(widget.rideId).notifier).open(reason, _text);
      _message.clear();
      if (mounted) setState(() => _reason = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final disputes = ref.watch(disputesProvider(widget.rideId));
    final mine = disputes.value ?? const <Dispute>[];
    final taken = {for (final d in mine) d.reason};
    final reasons = DisputeReason.values.where((r) => !taken.contains(r)).toList();

    return UmPage(
      appBar: AppBar(),
      title: l10n.disputeTitle,
      intro: l10n.disputeIntro,
      footer: [
        if (reasons.isNotEmpty)
          UmButton(
            label: l10n.disputeSend,
            expand: true,
            loading: _busy,
            onPressed: _reason == null || _busy ? null : _send,
          ),
      ],
      children: [
        if (disputes.isLoading && !disputes.hasValue)
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        if (mine.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Text(l10n.disputeYours, style: UmText.h3.copyWith(color: c.ink)),
          ),
          const SizedBox(height: UmSpace.s3),
          for (final d in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: UmSpace.s3),
              child: _DisputeCard(
                dispute: d,
                busy: _busy,
                onEscalate: () => _run(
                  () => ref.read(disputesProvider(widget.rideId).notifier).escalate(d.id, _text),
                  done: l10n.disputeEscalated,
                ),
              ),
            ),
          const SizedBox(height: UmSpace.s3),
        ],
        if (reasons.isNotEmpty) ...[
          Text(l10n.disputeReasonLabel, style: UmText.label.copyWith(color: c.brandStrong)),
          RadioGroup<DisputeReason>(
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
            child: Column(
              children: [
                for (final r in reasons)
                  RadioListTile<DisputeReason>(
                    contentPadding: EdgeInsets.zero,
                    value: r,
                    title: Text(reasonLabel(l10n, r)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: UmSpace.s3),
        ],
        // Le message sert aussi à expliquer un désaccord au moment de contester une décision.
        UmField(
          label: l10n.disputeMessageLabel,
          controller: _message,
          maxLines: 5,
          maxLength: 1000,
        ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
        if (disputes.hasError) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(
            apiErrorMessage(
              l10n,
              disputes.error is ApiException ? (disputes.error! as ApiException).code : null,
            ),
          ),
        ],
      ],
    );
  }
}

String reasonLabel(AppLocalizations l10n, DisputeReason reason) => switch (reason) {
  DisputeReason.cancellationPenalty => l10n.disputeReasonCancellation,
  DisputeReason.markedAbsent => l10n.disputeReasonAbsent,
  DisputeReason.payment => l10n.disputeReasonPayment,
  DisputeReason.driverIssue => l10n.disputeReasonDriver,
  DisputeReason.other => l10n.disputeReasonOther,
};

String explanationText(AppLocalizations l10n, String code) => switch (code) {
  'penalty_matches_timestamps' => l10n.explainPenaltyMatches,
  'penalty_recomputed' => l10n.explainPenaltyRecomputed,
  'no_penalty' => l10n.explainNoPenalty,
  'presence_validated' => l10n.explainPresenceValidated,
  'driver_confirmed_boarding' => l10n.explainDriverConfirmed,
  'no_presence_evidence' => l10n.explainNoPresence,
  'not_absent' => l10n.explainNotAbsent,
  _ => l10n.explainNeedsHuman,
};

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute, required this.busy, required this.onEscalate});

  final Dispute dispute;
  final bool busy;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chip = dispute.withTeam
        ? UmChip(label: l10n.disputePending, icon: Icons.mail_outline_rounded)
        : switch (dispute.decision) {
            DisputeDecision.corrected => UmChip(
              label: l10n.disputeCorrected,
              icon: Icons.check_circle_outline_rounded,
              tone: UmChipTone.success,
            ),
            _ => UmChip(label: l10n.disputeUpheld, icon: Icons.gavel_rounded),
          };
    return UmCard(
      title: reasonLabel(l10n, dispute.reason),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chip,
          const SizedBox(height: UmSpace.s3),
          TrustInfo(
            icon: dispute.withTeam ? Icons.mail_outline_rounded : Icons.info_outline_rounded,
            text: dispute.withTeam && dispute.explanation != 'driver_confirmed_boarding'
                ? l10n.disputeWithTeam
                : explanationText(l10n, dispute.explanation),
          ),
          if (!dispute.withTeam) ...[
            const SizedBox(height: UmSpace.s3),
            UmButton(
              label: l10n.disputeEscalate,
              variant: UmButtonVariant.secondary,
              onPressed: busy ? null : onEscalate,
            ),
          ],
        ],
      ),
    );
  }
}
