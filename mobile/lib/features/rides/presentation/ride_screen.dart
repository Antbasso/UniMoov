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
import '../../profile/presentation/person_avatar.dart';
import '../../proposals/domain/proposal.dart';
import '../../proposals/presentation/formatting.dart';
import '../../proposals/presentation/proposals_controller.dart';
import '../../trust/domain/trust.dart';
import '../../trust/presentation/cancel_sheet.dart';
import '../../trust/presentation/rating_card.dart';
import '../../trust/presentation/report_sheet.dart';
import '../../trust/presentation/trust_info.dart';
import '../domain/ride.dart';
import 'live_actions.dart';
import '../../chat/presentation/open_ride_chat.dart';
import 'live_controller.dart';
import 'ride_map.dart';
import 'trip_widgets.dart';
import 'rides_controller.dart';

/// Trajet confirmé (cahier §14), en un seul écran : la carte d'abord, puis qui monte et à
/// quelle heure, le prix en puces. Le chat est une icône en haut ; les actions rares (annuler,
/// signaler) sont dans le menu. Une fois terminé : la notation en tête, le reste replié.
class RideScreen extends ConsumerWidget {
  const RideScreen({super.key, required this.id, this.proposal});

  final String id;

  /// Proposition de la semaine (depuis l'accueil) : demandes et invitations encore en attente,
  /// montrées au conducteur comme provisoires.
  final Proposal? proposal;

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
      AsyncValue(:final value?) => _RideContent(ride: value, proposal: proposal),
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
  const _RideContent({required this.ride, this.proposal});

  final RideDetails ride;
  final Proposal? proposal;

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

  /// Conversation du trajet, dans l'onglet Messages.
  Future<void> _openChat() async {
    try {
      await openRideChat(context, ref, widget.ride.id);
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

  /// Conducteur : réponse à une demande de place encore en attente.
  Future<void> _answer(String userId, {required bool approve}) => _act(() async {
    final week = isoWeekOf(widget.ride.day);
    await ref
        .read(weekProposalsProvider(week).notifier)
        .answerRequest(widget.ride.id, userId, approve: approve);
    ref.invalidate(rideProvider(widget.ride.id));
  });

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final myId = ref.watch(meProvider.select((me) => me.value?.id));
    final myStop = ride.stopOf(myId);
    final live = ride.inProgress ? ref.watch(liveRideProvider(ride.id)) : null;
    final driverId = ride.driverStop?.userId;
    final driverLive = driverId == null ? null : live?.positions[driverId];
    final controller = ref.read(rideProvider(ride.id).notifier);
    // Proposition à jour (demandes, invitations) si l'accueil l'a déjà chargée.
    final week = isoWeekOf(ride.day);
    final proposal =
        ref.watch(weekProposalsProvider(week)).value?.where((p) => p.id == ride.id).firstOrNull ??
        widget.proposal;
    final aboard = {for (final s in ride.stops) ?s.userId};
    final pending = ride.isDriver
        ? [
            for (final p in proposal?.passengers ?? const <PublicPerson>[])
              if (personVisible(p) && p.status != 'accepted' && !aboard.contains(p.userId)) p,
          ]
        : const <PublicPerson>[];
    final cancellable =
        ride.editable ||
        (ride.inProgress && !ride.isDriver && myStop != null && !myStop.presenceValidated);
    final rate = ride.completed && !ride.markedAbsent;

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
      // À bord, pas encore à destination : il peut terminer son trajet (il paie sa part), après
      // un avertissement ; le conducteur est prévenu. Avant d'être à bord, il annule (menu).
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
    ];

    final map = RideMap(
      stops: ride.stops,
      route: ride.route,
      dashed: ride.routeEstimated,
      semanticLabel: l10n.rideMapLabel(ride.stops.length),
      live: driverLive == null ? null : LatLng(driverLive.lat, driverLive.lon),
      areas: [
        for (final p in pending)
          if (p.sector case (final lat, final lon))
            MapArea(lat: lat, lon: lon, name: p.firstName, provisional: true),
      ],
    );

    final people = <Widget>[
      for (final stop in ride.stops)
        _StopRow(
          stop: stop,
          isMe: stop.userId == myId,
          // La voiture sous le conducteur : on la reconnaît en arrivant au point de rendez-vous.
          vehicle: stop.kind == StopKind.driver ? ride.vehicleLabel : null,
          onTap: stop.userId == null || stop.userId == myId
              ? null
              : () => context.push(AppRoutes.person(stop.userId!)),
          actions: [
            if (stop.userId == myId && ride.editable && !ride.isDriver)
              UmButton(
                label: myStop!.isMeetingPoint
                    ? l10n.rideChangeMeetingPoint
                    : l10n.rideChooseMeetingPoint,
                icon: Icons.place_outlined,
                variant: UmButtonVariant.ghost,
                onPressed: () => context.push(AppRoutes.rideMeetingPoint(ride.id)),
              ),
          ],
        ),
      for (final person in pending)
        PersonRow(
          name: person.firstName,
          leading: PersonAvatar(name: person.firstName, photoUrl: person.photoUrl),
          onTap: () => context.push(AppRoutes.person(person.userId)),
          stats: personStats(l10n, person, isDriver: false),
          status: personStatusChip(l10n, person.status),
          actions: person.isRequest
              ? [
                  UmButton(
                    label: l10n.requestApprove,
                    loading: _busy,
                    onPressed: () => _answer(person.userId, approve: true),
                  ),
                  UmButton(
                    label: l10n.requestReject,
                    variant: UmButtonVariant.ghost,
                    onPressed: _busy ? null : () => _answer(person.userId, approve: false),
                  ),
                ]
              : const [],
        ),
      if (ride.editable && ride.isDriver)
        Align(
          alignment: Alignment.centerLeft,
          child: UmButton(
            label: l10n.rideAddPassengers,
            icon: Icons.person_add_alt_rounded,
            variant: UmButtonVariant.ghost,
            onPressed: () => context.push(AppRoutes.rideSuggestions(ride.id)),
          ),
        ),
    ];

    final details = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              formatTime(ride.time, l10n.localeName),
              style: UmText.h2.copyWith(color: c.ink),
            ),
          ),
          switch (ride.status) {
            'in_progress' => UmChip(
              label: l10n.rideStatusLive,
              icon: Icons.near_me_outlined,
              tone: UmChipTone.success,
            ),
            'completed' => UmChip(label: l10n.rideCompleted, icon: Icons.flag_outlined),
            _ => UmChip(
              label: l10n.rideStatusConfirmed,
              icon: Icons.check_circle_outline_rounded,
              tone: UmChipTone.success,
            ),
          },
        ],
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
      const SizedBox(height: UmSpace.s4),
      ...people,
      const SizedBox(height: UmSpace.s3),
      Divider(color: c.border),
      const SizedBox(height: UmSpace.s3),
      PriceBullets(price: ride.price, isDriver: ride.isDriver, distanceM: ride.distanceM),
      if (ride.routeEstimated) ...[
        const SizedBox(height: UmSpace.s3),
        Text(l10n.rideRouteEstimated, style: UmText.caption.copyWith(color: c.inkMuted)),
      ],
    ];

    final menu = <(String, VoidCallback)>[
      if (ride.completed) ...[
        (
          l10n.rideProblem,
          () => context.push(
            AppRoutes.dispute(
              ride.id,
              reason: ride.markedAbsent ? DisputeReason.markedAbsent : null,
            ),
          ),
        ),
        (l10n.reportAction, () => _report(myId)),
      ],
      if (cancellable) (ride.isDriver ? l10n.cancelRide : l10n.cancelMyPlace, _cancel),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tripTitle(l10n, ride.direction, ride.day),
          style: UmText.h3.copyWith(color: c.ink),
        ),
        actions: [
          // Chat du trajet (cahier §6), créé à la confirmation.
          IconButton(
            tooltip: l10n.rideChat,
            icon: Icon(Icons.chat_bubble_outline_rounded, color: c.brandStrong),
            onPressed: _openChat,
          ),
          if (menu.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: l10n.moreActions,
              icon: Icon(Icons.more_vert_rounded, color: c.ink),
              onSelected: (i) => menu[i].$2(),
              itemBuilder: (_) => [
                for (final (i, (label, _)) in menu.indexed)
                  PopupMenuItem(value: i, child: Text(label)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!rate) SizedBox(height: UmSize.mapHeight, child: map),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(UmSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rate
                      ? [
                          // Trajet terminé : seule la notation compte, le reste est replié.
                          RatingCard(rideId: ride.id),
                          const SizedBox(height: UmSpace.s4),
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.rideDetailsTitle,
                                style: UmText.body.copyWith(
                                  color: c.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                SizedBox(height: UmSize.sectorMiniMap, child: map),
                                const SizedBox(height: UmSpace.s4),
                                ...details,
                              ],
                            ),
                          ),
                        ]
                      : details,
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

/// Un arrêt sur une ligne : pastille (la même que sur la carte), qui, où, ⏱ heure, statut.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.isMe,
    this.vehicle,
    this.actions = const [],
    this.onTap,
  });

  final RideStop stop;
  final bool isMe;

  /// Modèle et couleur de la voiture (ligne du conducteur).
  final String? vehicle;
  final List<Widget> actions;

  /// Profil de la personne (sauf soi-même et le campus).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = switch (stop.kind) {
      StopKind.campus => stop.label,
      _ when isMe => l10n.rideYou,
      _ => stop.fullName ?? '',
    };
    // Domicile d'un autre : le serveur ne donne que le secteur, sans adresse.
    final place = stop.kind == StopKind.campus
        ? null
        : (stop.label.isEmpty ? l10n.rideStopApproximate : stop.label);
    final time = stop.eta == null ? null : formatTime(stop.eta!, l10n.localeName);
    // Fin de trajet d'un passager, à bord, ou point de rendez-vous.
    final Widget? status = stop.arrived
        ? UmChip(label: l10n.stopArrived, icon: Icons.where_to_vote_outlined)
        : stop.leftEarly
        ? UmChip(label: l10n.stopLeftEarly, icon: Icons.logout_rounded)
        : stop.presenceValidated
        ? UmChip(
            label: l10n.stopOnBoard,
            icon: Icons.check_circle_rounded,
            tone: UmChipTone.success,
          )
        : stop.isMeetingPoint
        ? UmChip(label: l10n.rideMeetingPoint, icon: Icons.place_outlined)
        : null;

    return Semantics(
      container: true,
      label: [
        l10n.rideStopSemantic(stop.order + 1, name, place ?? '', time ?? ''),
        if (vehicle != null) l10n.rideVehicleSemantic(vehicle!),
        if (status case UmChip(:final label)) label,
      ].join(', '),
      button: onTap != null,
      excludeSemantics: actions.isEmpty,
      child: PersonRow(
        name: name,
        leading: SizedBox.square(
          dimension: UmSize.avatar,
          child: Center(
            child: StopBadge(stop: stop, size: UmSize.stopBadge),
          ),
        ),
        subtitle: place,
        stats: [
          if (time != null)
            UmStat(icon: Icons.schedule_rounded, value: time, semantic: l10n.rideStopAround(time)),
          if (vehicle != null)
            UmStat(
              icon: Icons.directions_car_filled_outlined,
              value: vehicle!,
              semantic: l10n.rideVehicleSemantic(vehicle!),
            ),
        ],
        status: status,
        actions: actions,
        onTap: onTap,
      ),
    );
  }
}
