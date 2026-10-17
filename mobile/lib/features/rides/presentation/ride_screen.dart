import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../proposals/domain/proposal.dart';
import '../../chat/data/chat_api.dart';
import '../../proposals/presentation/formatting.dart';
import '../../proposals/presentation/proposals_controller.dart';
import '../../trust/domain/trust.dart';
import '../../trust/presentation/cancel_sheet.dart';
import '../../trust/presentation/rating_card.dart';
import '../../trust/presentation/report_sheet.dart';
import '../../trust/presentation/trust_info.dart';
import '../domain/ride.dart';
import 'live_actions.dart';
import 'live_controller.dart';
import 'ride_map.dart';
import 'rides_controller.dart';

/// Trajet confirmé (cahier §14) : carte, arrêts dans l'ordre avec l'heure de passage,
/// prix estimé. Passager : point de rendez-vous. Conducteur : ajouter des passagers.
class RideScreen extends ConsumerWidget {
  const RideScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final ride = ref.watch(rideProvider(id));

    // Erreur d'abord (même avec un ancien contenu) ; pendant un rechargement, le contenu reste affiché.
    return switch (ride) {
      AsyncError(:final error) => UmPage(
        appBar: AppBar(),
        children: [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          const SizedBox(height: UmSpace.s3),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(rideProvider(id)),
          ),
        ],
      ),
      AsyncValue(:final value?) => _RideContent(ride: value),
      _ => UmPage(
        appBar: AppBar(),
        children: [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        ],
      ),
    };
  }
}

class _RideContent extends ConsumerStatefulWidget {
  const _RideContent({required this.ride});

  final RideDetails ride;

  @override
  ConsumerState<_RideContent> createState() => _RideContentState();
}

class _RideContentState extends ConsumerState<_RideContent> {
  bool _busy = false;
  String? _errorCode;

  /// Action sur le trajet (présence, clôture) : chargement, puis message ou erreur.
  Future<void> _act(Future<void> Function() action, {String? done}) async {
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

  /// Annulation après acceptation (cahier §8) : pénalité annoncée, puis retour à l'accueil.
  Future<void> _cancel() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final done = await showCancelSheet(context, widget.ride.id);
    if (done == null) return;
    ref.invalidate(weekProposalsProvider);
    messenger.showSnackBar(SnackBar(content: Text(done)));
    router.go(AppRoutes.home);
  }

  Future<void> _openChat() async {
    final router = GoRouter.of(context);
    try {
      final chat = await ref.read(chatApiProvider).rideConversation(widget.ride.id);
      await router.push(AppRoutes.conversation(chat.id));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    }
  }

  Future<void> _report(String? myId) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = AppLocalizations.of(context).reportDone;
    final people = [
      for (final s in widget.ride.stops)
        if (s.userId case final id? when id != myId) (userId: id, name: s.fullName ?? ''),
    ];
    if (await showReportSheet(context, people)) {
      messenger.showSnackBar(SnackBar(content: Text(done)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final myId = ref.watch(meProvider.select((me) => me.value?.id));
    final day = formatDayInline(ride.day, l10n.localeName);
    final title = ride.direction == Direction.toCampus
        ? l10n.proposalTitleTo(day)
        : l10n.proposalTitleFrom(day);
    final myStop = ride.stopOf(myId);
    final live = ride.inProgress ? ref.watch(liveRideProvider(ride.id)) : null;
    final driverId = ride.driverStop?.userId;
    final driverLive = driverId == null ? null : live?.positions[driverId];
    final controller = ref.read(rideProvider(ride.id).notifier);
    final footer = <Widget>[
      if (ride.isDriver && (ride.editable || ride.inProgress))
        UmButton(
          label: l10n.openDeparture,
          icon: Icons.navigation_outlined,
          expand: true,
          onPressed: () => context.push(AppRoutes.rideDeparture(ride.id)),
        ),
      if (!ride.isDriver && ride.inProgress && myStop != null && !myStop.presenceValidated)
        UmButton(
          label: l10n.confirmPresence,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : () => _act(controller.confirmPresence, done: l10n.presenceDone),
        ),
      // À bord, pas encore à destination : il peut terminer son trajet (et ne pas le payer),
      // après un avertissement ; le conducteur est prévenu. Avant d'être à bord, il annule.
      if (!ride.isDriver &&
          ride.inProgress &&
          myStop != null &&
          myStop.presenceValidated &&
          !myStop.ended)
        UmButton(
          label: l10n.finishMyTrip,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: _busy
              ? null
              : () async {
                  if (!await confirmFinishMyTrip(context)) return;
                  await _act(controller.finish, done: l10n.finishMyTripDone);
                },
        ),
      if (ride.editable && ride.isDriver)
        UmButton(
          label: l10n.rideAddPassengers,
          variant: UmButtonVariant.secondary,
          expand: true,
          onPressed: () => context.push(AppRoutes.rideSuggestions(ride.id)),
        ),
      if (ride.editable && !ride.isDriver && myStop != null)
        UmButton(
          label: myStop.isMeetingPoint ? l10n.rideChangeMeetingPoint : l10n.rideChooseMeetingPoint,
          variant: UmButtonVariant.secondary,
          expand: true,
          onPressed: () => context.push(AppRoutes.rideMeetingPoint(ride.id)),
        ),
      if (ride.editable ||
          (ride.inProgress && !ride.isDriver && myStop != null && !myStop.presenceValidated))
        UmButton(
          label: ride.isDriver ? l10n.cancelRide : l10n.cancelMyPlace,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: _cancel,
        ),
      if (ride.completed) ...[
        UmButton(
          label: l10n.rideProblem,
          variant: UmButtonVariant.secondary,
          expand: true,
          onPressed: () => context.push(
            AppRoutes.dispute(
              ride.id,
              reason: ride.markedAbsent ? DisputeReason.markedAbsent : null,
            ),
          ),
        ),
        UmButton(
          label: l10n.reportAction,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: () => _report(myId),
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Chat du trajet (cahier §6), créé à la confirmation.
          IconButton(
            tooltip: l10n.rideChat,
            icon: Icon(Icons.chat_bubble_outline_rounded, color: c.brandStrong),
            onPressed: _openChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: UmSize.mapHeight,
              child: RideMap(
                stops: ride.stops,
                route: ride.route,
                dashed: ride.routeEstimated,
                semanticLabel: l10n.rideMapLabel(ride.stops.length),
                live: driverLive == null ? null : LatLng(driverLive.lat, driverLive.lon),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(UmSpace.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: UmText.h1.copyWith(color: c.ink)),
                    ),
                    const SizedBox(height: UmSpace.s3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: switch (ride.status) {
                        'in_progress' => UmChip(
                          label: l10n.rideInProgress,
                          icon: Icons.near_me_outlined,
                          tone: UmChipTone.success,
                        ),
                        'completed' => UmChip(label: l10n.rideCompleted, icon: Icons.flag_outlined),
                        _ => UmChip(
                          label: l10n.proposalConfirmed,
                          icon: Icons.check_circle_outline_rounded,
                          tone: UmChipTone.success,
                        ),
                      },
                    ),
                    if (live != null && !ride.isDriver) ...[
                      const SizedBox(height: UmSpace.s3),
                      _LiveBanner(
                        onShare: live.sharing ? null : () => shareLocation(context, ref, ride.id),
                        live: live,
                        driver: driverLive,
                        myEta: myId == null ? null : live.etas[myId],
                      ),
                    ],
                    if (myStop != null && !ride.isDriver && myStop.arrived) ...[
                      const SizedBox(height: UmSpace.s3),
                      TrustInfo(icon: Icons.where_to_vote_outlined, text: l10n.tripArrived),
                    ] else if (myStop != null && !ride.isDriver && myStop.leftEarly) ...[
                      const SizedBox(height: UmSpace.s3),
                      TrustInfo(icon: Icons.logout_rounded, text: l10n.tripLeftEarly),
                    ] else if (myStop != null &&
                        !ride.isDriver &&
                        myStop.presenceValidated &&
                        !ride.completed) ...[
                      const SizedBox(height: UmSpace.s3),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: UmChip(
                          label: l10n.presenceOnBoard,
                          icon: Icons.verified_outlined,
                          tone: UmChipTone.success,
                        ),
                      ),
                    ],
                    if (ride.completed && ride.markedAbsent) ...[
                      const SizedBox(height: UmSpace.s3),
                      TrustInfo(icon: Icons.person_off_outlined, text: l10n.rideAbsent),
                    ],
                    if (_errorCode != null) ...[
                      const SizedBox(height: UmSpace.s3),
                      UmErrorText(apiErrorMessage(l10n, _errorCode)),
                    ],
                    if (ride.routeEstimated) ...[
                      const SizedBox(height: UmSpace.s3),
                      Text(
                        l10n.rideRouteEstimated,
                        style: UmText.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                    // Arrêts d'abord : qui, où et à quelle heure est l'information principale.
                    const SizedBox(height: UmSpace.s5),
                    Semantics(
                      header: true,
                      child: Text(l10n.rideStopsTitle, style: UmText.h3.copyWith(color: c.ink)),
                    ),
                    const SizedBox(height: UmSpace.s3),
                    for (final stop in ride.stops) _StopRow(stop: stop, isMe: stop.userId == myId),
                    const SizedBox(height: UmSpace.s3),
                    _PriceCard(price: ride.price, isDriver: ride.isDriver),
                    if (ride.completed && !ride.markedAbsent) ...[
                      const SizedBox(height: UmSpace.s4),
                      RatingCard(rideId: ride.id),
                    ],
                  ],
                ),
              ),
            ),
            if (footer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
                child: Column(children: footer),
              ),
          ],
        ),
      ),
    );
  }
}

/// Passager : heure d'arrivée du conducteur, ou sa dernière position connue après 30 s.
class _LiveBanner extends ConsumerStatefulWidget {
  const _LiveBanner({required this.live, required this.driver, required this.myEta, this.onShare});

  final LiveState live;

  /// Ma position n'est pas encore partagée : action proposée dans le bandeau du suivi.
  final VoidCallback? onShare;
  final LivePosition? driver;
  final DateTime? myEta;

  @override
  ConsumerState<_LiveBanner> createState() => _LiveBannerState();
}

class _LiveBannerState extends ConsumerState<_LiveBanner> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final now = ref.watch(clockProvider)();
    final driver = widget.driver;
    final text = switch ((widget.live, driver)) {
      (LiveState(ended: true), _) => l10n.liveEnded,
      (_, final d?) when now.difference(d.at) > staleAfter => l10n.liveLastKnown(
        formatTime(d.at, l10n.localeName),
      ),
      (_, _?) when widget.myEta != null => l10n.liveDriverEta(
        formatTime(widget.myEta!, l10n.localeName),
      ),
      (LiveState(connected: false), _) => l10n.liveReconnecting,
      _ => l10n.liveWaiting,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(UmSpace.s3),
        decoration: BoxDecoration(
          color: c.surfaceTint,
          borderRadius: BorderRadius.circular(UmRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car_rounded, size: UmSize.iconMd, color: c.brandStrong),
                const SizedBox(width: UmSpace.s2),
                Expanded(
                  child: Text(text, style: UmText.body.copyWith(color: c.ink)),
                ),
              ],
            ),
            if (widget.onShare != null && !widget.live.ended) ...[
              const SizedBox(height: UmSpace.s2),
              UmButton(
                label: l10n.shareLocation,
                icon: Icons.my_location_rounded,
                variant: UmButtonVariant.secondary,
                onPressed: widget.onShare,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.price, required this.isDriver});

  final RidePrice? price;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = price;
    if (p == null) return UmCard(body: l10n.ridePriceUnknown);
    final c = context.umColors;
    String euros(int cents) => UmRideCard.formatPrice(cents, l10n.localeName);
    final amount = euros((isDriver ? p.youReceiveCents : p.youPayCents) ?? 0);
    return UmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prix en UniMoov Display, comme sur la carte de trajet.
          Semantics(
            label: isDriver ? l10n.ridePriceYouReceive(amount) : l10n.ridePriceYouPay(amount),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDriver ? l10n.ridePriceReceiveLabel : l10n.ridePricePayLabel,
                  style: UmText.label.copyWith(color: c.inkMuted),
                ),
                Text(amount, style: UmText.h2.copyWith(color: c.brandStrong)),
              ],
            ),
          ),
          const SizedBox(height: UmSpace.s2),
          Text(
            l10n.ridePriceDetail(euros(p.totalCostCents), p.persons, euros(p.commissionCents)),
            style: UmText.bodySm.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isMe});

  final RideStop stop;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final name = switch (stop.kind) {
      StopKind.campus => stop.label,
      _ when isMe => l10n.rideYou,
      _ => stop.fullName ?? '',
    };
    // Domicile d'un autre passager : le serveur ne donne que le secteur, sans adresse.
    final place = stop.kind == StopKind.campus
        ? null
        : (stop.label.isEmpty ? l10n.rideStopApproximate : stop.label);
    final time = stop.eta == null ? null : formatTime(stop.eta!, l10n.localeName);
    // Fin de trajet d'un passager : arrivé (il paie) ou parti avant (il ne paie pas).
    final (String, IconData)? done = stop.arrived
        ? (l10n.stopArrived, Icons.where_to_vote_outlined)
        : stop.leftEarly
        ? (l10n.stopLeftEarly, Icons.logout_rounded)
        : null;

    return Semantics(
      container: true,
      label: [
        l10n.rideStopSemantic(stop.order + 1, name, place ?? '', time ?? ''),
        ?done?.$1,
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: UmSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StopBadge(stop: stop, size: UmSize.stopBadge),
            const SizedBox(width: UmSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                  ),
                  if (place != null) Text(place, style: UmText.bodySm.copyWith(color: c.inkMuted)),
                  if (stop.isMeetingPoint) ...[
                    const SizedBox(height: UmSpace.s1),
                    UmChip(label: l10n.rideMeetingPoint, icon: Icons.place_outlined),
                  ],
                  if (done != null) ...[
                    const SizedBox(height: UmSpace.s1),
                    UmChip(label: done.$1, icon: done.$2),
                  ],
                ],
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: UmSpace.s3),
              Text(l10n.rideStopAround(time), style: UmText.bodySm.copyWith(color: c.ink)),
            ],
          ],
        ),
      ),
    );
  }
}
