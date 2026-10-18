import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/person_avatar.dart';
import '../../rides/data/rides_api.dart';
import '../../rides/domain/ride.dart';
import '../../rides/presentation/ride_map.dart';
import '../../rides/presentation/ride_screen.dart';
import '../../rides/presentation/trip_widgets.dart';
import '../../trust/presentation/cancel_sheet.dart';
import '../../wallet/presentation/insufficient_funds_dialog.dart';
import '../domain/proposal.dart';
import 'formatting.dart';
import 'proposals_controller.dart';

/// Tracé d'un trajet proposé (avant confirmation).
final ridePreviewProvider = FutureProvider.autoDispose.family<RidePreview, String>(
  (ref, id) => ref.watch(ridesApiProvider).preview(id),
  retry: (retryCount, error) => null,
);

/// Un trajet de la semaine, en un seul écran. Confirmé : l'écran du trajet (carte, arrêts,
/// prix, chat). Sinon : la carte du trajet proposé tout de suite, les personnes dessous (et sur
/// la carte, en provisoire tant qu'elles n'ont pas accepté), puis accepter ou refuser.
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
      ref.invalidate(ridePreviewProvider(widget.id));
      if (popAfter && router.canPop()) router.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      // Solde trop bas pour le prix maximal : explication et recharge (cahier §5).
      if (error.code == 'insufficient_funds') return showInsufficientFunds(context);
      setState(() => _errorCode = error.code);
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
    // Engagé sur un trajet confirmé : directement l'écran du trajet, sans clic de plus.
    if (proposal.state == ProposalState.confirmed) {
      return RideScreen(id: proposal.id, proposal: proposal);
    }
    final open = proposal.rideStatus == 'proposed' || proposal.rideStatus == 'confirmed';

    final status = switch (proposal.state) {
      ProposalState.waiting => UmChip(
        label: l10n.rideStatusWaiting,
        icon: Icons.hourglass_empty_rounded,
      ),
      ProposalState.requested => UmChip(
        label: l10n.requestSent,
        icon: Icons.hourglass_empty_rounded,
      ),
      ProposalState.cancelled => UmChip(
        label: l10n.rideStatusCancelled,
        icon: Icons.cancel_outlined,
        tone: UmChipTone.danger,
      ),
      _ => UmChip(label: l10n.rideStatusProposed, icon: Icons.schedule_rounded),
    };
    final people = proposal.isDriver
        ? proposal.passengers.where(personVisible).toList()
        : [?proposal.driver];

    final footer = <Widget>[
      if (proposal.canAnswer) ...[
        UmButton(
          label: l10n.accept,
          expand: true,
          loading: _busy,
          onPressed: () => _run(() => controller.accept(proposal.id)),
        ),
        // Côte à côte s'il y a la place, l'un sous l'autre sinon (texte agrandi).
        OverflowBar(
          alignment: MainAxisAlignment.spaceEvenly,
          overflowAlignment: OverflowBarAlignment.center,
          children: [
            UmButton(
              label: l10n.decline,
              variant: UmButtonVariant.ghost,
              onPressed: _busy
                  ? null
                  : () => _run(() => controller.decline(proposal.id), popAfter: true),
            ),
            if (!proposal.isDriver)
              UmButton(
                label: l10n.seeOthers,
                variant: UmButtonVariant.ghost,
                onPressed: _busy
                    ? null
                    : () => context.push(AppRoutes.alternatives(widget.week, proposal.id)),
              ),
          ],
        ),
      ],
      if (proposal.state == ProposalState.requested)
        UmButton(
          label: l10n.requestWithdraw,
          variant: UmButtonVariant.ghost,
          expand: true,
          loading: _busy,
          onPressed: () => _run(() => controller.decline(proposal.id), popAfter: true),
        ),
      // Engagé (accepté) : annuler est une annulation avec pénalité, plus un simple refus.
      if (proposal.myStatus == 'accepted' && proposal.state != ProposalState.cancelled && open)
        UmButton(
          label: proposal.isDriver ? l10n.cancelRide : l10n.cancelMyPlace,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: _busy ? null : () => _cancel(proposal.id),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tripTitle(l10n, proposal.direction, proposal.day),
          style: UmText.h3.copyWith(color: c.ink),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: UmSize.mapHeight,
              child: _PreviewMap(proposal: proposal),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(UmSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatTime(proposal.time, l10n.localeName),
                            style: UmText.h2.copyWith(color: c.ink),
                          ),
                        ),
                        status,
                      ],
                    ),
                    if (proposal.priceCents case final cents?) ...[
                      const SizedBox(height: UmSpace.s1),
                      Text(
                        proposal.isDriver
                            ? l10n.proposalPriceReceive(
                                UmRideCard.formatPrice(cents, l10n.localeName),
                              )
                            : l10n.proposalPricePay(UmRideCard.formatPrice(cents, l10n.localeName)),
                        style: UmText.body.copyWith(color: c.brandStrong),
                      ),
                    ],
                    const SizedBox(height: UmSpace.s4),
                    if (proposal.isDriver && people.isEmpty)
                      Text(
                        l10n.proposalNoPassengers,
                        style: UmText.body.copyWith(color: c.inkMuted),
                      ),
                    for (final person in people)
                      PersonRow(
                        name: person.firstName,
                        leading: PersonAvatar(name: person.firstName, photoUrl: person.photoUrl),
                        // Toucher la personne : son profil (formation, âge, centres d'intérêt).
                        onTap: () => context.push(AppRoutes.person(person.userId)),
                        stats: personStats(l10n, person, isDriver: !proposal.isDriver),
                        status: personStatusChip(l10n, person.status),
                        // Conducteur : une demande de place attend sa réponse.
                        actions: proposal.isDriver && person.isRequest
                            ? [
                                UmButton(
                                  label: l10n.requestApprove,
                                  loading: _busy,
                                  onPressed: () => _run(
                                    () => controller.answerRequest(
                                      proposal.id,
                                      person.userId,
                                      approve: true,
                                    ),
                                  ),
                                ),
                                UmButton(
                                  label: l10n.requestReject,
                                  variant: UmButtonVariant.ghost,
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => controller.answerRequest(
                                            proposal.id,
                                            person.userId,
                                            approve: false,
                                          ),
                                        ),
                                ),
                              ]
                            : const [],
                      ),
                    // Le conducteur engagé peut proposer des places, même avant la confirmation.
                    if (proposal.isDriver && proposal.myStatus == 'accepted' && open)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: UmButton(
                          label: l10n.rideAddPassengers,
                          icon: Icons.person_add_alt_rounded,
                          variant: UmButtonVariant.ghost,
                          onPressed: () => context.push(AppRoutes.rideSuggestions(proposal.id)),
                        ),
                      ),
                    const SizedBox(height: UmSpace.s3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: UmSize.iconSm, color: c.inkMuted),
                        const SizedBox(width: UmSpace.s2),
                        Expanded(
                          child: Text(
                            l10n.privacyNote,
                            style: UmText.caption.copyWith(color: c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    if (_errorCode != null) ...[
                      const SizedBox(height: UmSpace.s4),
                      UmErrorText(apiErrorMessage(l10n, _errorCode)),
                    ],
                  ],
                ),
              ),
            ),
            if (footer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(UmSpace.s5, 0, UmSpace.s5, UmSpace.s4),
                child: Column(
                  children: [
                    for (var i = 0; i < footer.length; i++) ...[
                      if (i > 0) const SizedBox(height: UmSpace.s2),
                      footer[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un trajet proposé : tracé du conducteur (sans les abords des domiciles), mon point,
/// le campus, et chaque personne en zone de 750 m, provisoire tant qu'elle n'a pas accepté.
class _PreviewMap extends ConsumerWidget {
  const _PreviewMap({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(ridePreviewProvider(proposal.id));
    // Cadrage fait une fois, à la création de la carte : on attend le tracé (ou son échec).
    if (async.isLoading && !async.hasValue) {
      return ColoredBox(
        color: context.umColors.surfaceTint,
        child: Semantics(
          label: l10n.loading,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final preview = async.value;
    final people = [
      if (proposal.isDriver) ...proposal.passengers.where(personVisible) else ?proposal.driver,
    ];
    final me = preview?.me;
    final campus = preview?.campus;
    return RideMap(
      route: preview?.route ?? const [],
      dashed: preview?.estimated ?? false,
      semanticLabel: l10n.proposalMapLabel(people.length),
      stops: [
        if (campus != null)
          RideStop(
            order: 0,
            kind: StopKind.campus,
            label: preview!.campusName,
            lat: campus.$1,
            lon: campus.$2,
            isMeetingPoint: false,
          ),
        if (me != null && proposal.isDriver)
          RideStop(
            order: 0,
            kind: StopKind.driver,
            label: '',
            lat: me.$1,
            lon: me.$2,
            isMeetingPoint: false,
          ),
      ],
      pin: me == null || proposal.isDriver ? null : LatLng(me.$1, me.$2),
      areas: [
        for (final person in people)
          if (person.sector case (final lat, final lon))
            MapArea(
              lat: lat,
              lon: lon,
              name: person.firstName,
              driver: !proposal.isDriver,
              provisional: person.status != 'accepted',
            ),
      ],
    );
  }
}
