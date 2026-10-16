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

  /// Avec des demandes existantes, le formulaire d'une nouvelle demande est replié.
  bool _another = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

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
    final text = _message.text.trim();
    await _run(() async {
      await ref
          .read(disputesProvider(widget.rideId).notifier)
          .open(reason, text.isEmpty ? null : text);
      _message.clear();
      if (mounted) {
        setState(() {
          _reason = null;
          _another = false;
        });
      }
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
    final showForm = disputes.hasValue && reasons.isNotEmpty && (mine.isEmpty || _another);

    return UmPage(
      appBar: AppBar(),
      title: l10n.disputeTitle,
      intro: l10n.disputeIntro,
      footer: [
        if (showForm)
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
        if (disputes.hasError) ...[
          UmErrorText(
            apiErrorMessage(
              l10n,
              disputes.error is ApiException ? (disputes.error! as ApiException).code : null,
            ),
          ),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(disputesProvider(widget.rideId)),
          ),
        ],
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
                onEscalate: (message) => _run(
                  () => ref.read(disputesProvider(widget.rideId).notifier).escalate(d.id, message),
                  done: l10n.disputeEscalated,
                ),
              ),
            ),
          if (reasons.isNotEmpty && !_another)
            Align(
              alignment: Alignment.centerLeft,
              child: UmButton(
                label: l10n.disputeAnother,
                variant: UmButtonVariant.ghost,
                onPressed: () => setState(() => _another = true),
              ),
            ),
        ],
        if (showForm) ...[
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
          if (_reason == null)
            Text(l10n.disputeChooseReason, style: UmText.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: UmSpace.s3),
          UmField(
            label: l10n.disputeMessageLabel,
            controller: _message,
            maxLines: 5,
            maxLength: 1000,
          ),
        ],
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s3),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
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

/// Demande et sa décision ; « Je ne suis pas d'accord » déplie le message à l'équipe.
class _DisputeCard extends StatefulWidget {
  const _DisputeCard({required this.dispute, required this.busy, required this.onEscalate});

  final Dispute dispute;
  final bool busy;
  final Future<void> Function(String? message) onEscalate;

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  final _why = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dispute = widget.dispute;
    final chip = dispute.withTeam
        ? UmChip(label: l10n.disputePending, icon: Icons.mail_outline_rounded)
        : switch (dispute.decision) {
            DisputeDecision.corrected => UmChip(
              label: l10n.disputeCorrected,
              icon: Icons.check_circle_outline_rounded,
              tone: UmChipTone.success,
            ),
            _ => UmChip(label: l10n.disputeUpheld, icon: Icons.info_outline_rounded),
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
            if (!_open)
              UmButton(
                label: l10n.disputeEscalate,
                variant: UmButtonVariant.secondary,
                onPressed: widget.busy ? null : () => setState(() => _open = true),
              )
            else ...[
              UmField(label: l10n.disputeWhy, controller: _why, maxLines: 5, maxLength: 1000),
              const SizedBox(height: UmSpace.s2),
              UmButton(
                label: l10n.disputeSendTeam,
                loading: widget.busy,
                onPressed: widget.busy
                    ? null
                    : () => widget.onEscalate(_why.text.trim().isEmpty ? null : _why.text.trim()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
