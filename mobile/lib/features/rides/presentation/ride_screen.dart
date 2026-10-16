import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../proposals/domain/proposal.dart';
import '../../proposals/presentation/formatting.dart';
import '../domain/ride.dart';
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

    return switch (ride) {
      AsyncData(:final value) => _RideContent(ride: value),
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

class _RideContent extends ConsumerWidget {
  const _RideContent({required this.ride});

  final RideDetails ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final myId = ref.watch(meProvider.select((me) => me.value?.id));
    final day = formatDayInline(ride.day, l10n.localeName);
    final title = ride.direction == Direction.toCampus
        ? l10n.proposalTitleTo(day)
        : l10n.proposalTitleFrom(day);
    final myStop = ride.stopOf(myId);

    final footer = <Widget>[
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
    ];

    return Scaffold(
      appBar: AppBar(),
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
                      child: UmChip(
                        label: l10n.proposalConfirmed,
                        icon: Icons.check_circle_outline_rounded,
                        tone: UmChipTone.success,
                      ),
                    ),
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

    return Semantics(
      container: true,
      label: l10n.rideStopSemantic(stop.order + 1, name, place ?? '', time ?? ''),
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
