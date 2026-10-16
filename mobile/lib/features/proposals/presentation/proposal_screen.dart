import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../trust/presentation/cancel_sheet.dart';
import '../domain/proposal.dart';
import 'formatting.dart';
import 'proposals_controller.dart';

/// Détail d'une proposition : informations publiques seulement, puis accepter, refuser ou
/// voir d'autres voitures.
class ProposalScreen extends ConsumerStatefulWidget {
  const ProposalScreen({super.key, required this.week, required this.id});

  final String week;
  final String id;

  @override
  ConsumerState<ProposalScreen> createState() => _ProposalScreenState();
}

class _ProposalScreenState extends ConsumerState<ProposalScreen> {
  bool _busy = false;
  String? _errorCode;

  /// Annulation après acceptation : la feuille annonce la pénalité, puis la semaine est relue.
  Future<void> _cancel(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final done = await showCancelSheet(context, id);
    if (done == null) return;
    ref.invalidate(weekProposalsProvider);
    messenger.showSnackBar(SnackBar(content: Text(done)));
    if (router.canPop()) router.pop();
  }

  Future<void> _run(Future<void> Function() action, {bool popAfter = false}) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final router = GoRouter.of(context);
    try {
      await action();
      if (popAfter && router.canPop()) router.pop();
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
    final controller = ref.read(weekProposalsProvider(widget.week).notifier);
    final proposals = ref.watch(weekProposalsProvider(widget.week));

    final proposal = proposals.value?.where((p) => p.id == widget.id).firstOrNull;
    if (proposal == null) {
      return UmPage(
        appBar: AppBar(),
        children: [
          if (proposals.isLoading)
            Semantics(label: l10n.loading, child: const LinearProgressIndicator())
          else
            UmErrorText(l10n.errorProposalCancelled),
        ],
      );
    }

    final day = formatDayInline(proposal.day, l10n.localeName);
    final title = proposal.direction == Direction.toCampus
        ? l10n.proposalTitleTo(day)
        : l10n.proposalTitleFrom(day);
    final status = switch (proposal.state) {
      ProposalState.confirmed => UmChip(
        label: l10n.proposalConfirmed,
        icon: Icons.check_circle_outline_rounded,
        tone: UmChipTone.success,
      ),
      ProposalState.waiting => UmChip(
        label: l10n.proposalWaiting,
        icon: Icons.hourglass_empty_rounded,
      ),
      ProposalState.cancelled => UmChip(
        label: l10n.rideStatusCancelled,
        icon: Icons.cancel_outlined,
        tone: UmChipTone.danger,
      ),
      ProposalState.proposed => null,
    };

    return UmPage(
      appBar: AppBar(),
      title: title,
      intro: l10n.proposalTime(formatTime(proposal.time, l10n.localeName)),
      footer: [
        if (proposal.canAnswer) ...[
          UmButton(
            label: l10n.accept,
            expand: true,
            loading: _busy,
            onPressed: () => _run(() => controller.accept(proposal.id)),
          ),
          if (!proposal.isDriver)
            UmButton(
              label: l10n.seeOthers,
              variant: UmButtonVariant.secondary,
              expand: true,
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.alternatives(widget.week, proposal.id)),
            ),
          UmButton(
            label: l10n.decline,
            variant: UmButtonVariant.ghost,
            expand: true,
            onPressed: _busy
                ? null
                : () => _run(() => controller.decline(proposal.id), popAfter: true),
          ),
        ],
        if (proposal.state == ProposalState.confirmed)
          UmButton(
            label: l10n.rideMapOpen,
            expand: true,
            onPressed: () => context.push(AppRoutes.ride(proposal.id)),
          ),
        // Engagé (accepté) : annuler est une annulation avec pénalité, plus un simple refus.
        if (proposal.myStatus == 'accepted' && proposal.state != ProposalState.cancelled)
          UmButton(
            label: proposal.isDriver ? l10n.cancelRide : l10n.cancelMyPlace,
            variant: UmButtonVariant.ghost,
            expand: true,
            onPressed: _busy ? null : () => _cancel(proposal.id),
          ),
        // Le conducteur engagé peut proposer des places, même avant la confirmation.
        if (proposal.isDriver &&
            proposal.myStatus == 'accepted' &&
            proposal.state != ProposalState.cancelled)
          UmButton(
            label: l10n.rideAddPassengers,
            variant: UmButtonVariant.secondary,
            expand: true,
            onPressed: () => context.push(AppRoutes.rideSuggestions(proposal.id)),
          ),
      ],
      children: [
        if (status != null) ...[
          Align(alignment: Alignment.centerLeft, child: status),
          const SizedBox(height: UmSpace.s4),
        ],
        Text(
          proposal.isDriver ? l10n.proposalPassengersIntro : l10n.proposalDriverIntro,
          style: UmText.label.copyWith(color: c.brandStrong),
        ),
        const SizedBox(height: UmSpace.s2),
        if (proposal.isDriver && proposal.passengers.isEmpty)
          Text(l10n.proposalNoPassengers, style: UmText.body.copyWith(color: c.inkMuted)),
        for (final person in proposal.isDriver ? proposal.passengers : [proposal.driver!])
          Padding(
            padding: const EdgeInsets.only(bottom: UmSpace.s3),
            child: PersonCard(person: person),
          ),
        // Le détour est déjà dans la carte ; un texte collé sous son ombre manquerait de contraste.
        const SizedBox(height: UmSpace.s4),
        Text(l10n.privacyNote, style: UmText.caption.copyWith(color: c.inkMuted)),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}

/// Personne avant acceptation : prénom, score, détour, secteur approximatif.
class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.person});

  final PublicPerson person;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UmCard(
      title: person.firstName,
      body: l10n.personDetails(person.scoreOutOfFive, person.detourMinutes),
    );
  }
}
