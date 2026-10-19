import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../domain/ride.dart';
import 'ride_map.dart';
import 'rides_controller.dart';

/// Point de rencontre (cahier §14). Passager : il remplace son adresse auprès du conducteur,
/// avant ou après avoir accepté le trajet (le serveur vérifie qu'il reste proche du domicile).
/// Conducteur (`forUserId`) : il propose un point au passager, qui l'accepte ou le refuse.
/// Le tracé reste visible ; les parkings publics et aires de covoiturage sont mis en évidence ;
/// toucher la carte suffit, sans adresse à saisir.
class MeetingPointScreen extends ConsumerStatefulWidget {
  const MeetingPointScreen({super.key, required this.id, this.forUserId, this.forName});

  final String id;

  /// Conducteur : le passager à qui il propose un point.
  final String? forUserId;
  final String? forName;

  @override
  ConsumerState<MeetingPointScreen> createState() => _MeetingPointScreenState();
}

class _MeetingPointScreenState extends ConsumerState<MeetingPointScreen> {
  final _label = TextEditingController();
  LatLng? _pin;
  bool _initialised = false;

  /// Le nom vient de la carte (lieu touché, ou « point choisi ») : il suit le prochain choix.
  bool _autoLabel = false;
  bool _busy = false;
  String? _errorCode;

  bool get _proposing => widget.forUserId != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _place(LatLng point, String label) {
    setState(() {
      _pin = point;
      if (_label.text.trim().isEmpty || _autoLabel) {
        _label.text = label;
        _autoLabel = true;
      }
    });
  }

  void _pickSpot(MeetingSpot spot) {
    final l10n = AppLocalizations.of(context);
    final kind = spot.kind == SpotKind.carpool ? l10n.spotCarpool : l10n.spotParking;
    // Un lieu touché donne toujours son nom, même après une saisie.
    setState(() => _autoLabel = true);
    _place(LatLng(spot.lat, spot.lon), spot.name ?? kind);
  }

  Future<void> _save(MeetingPoint? point, String done) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final actions = ref.read(meetingPointActionsProvider);
    try {
      if (_proposing) {
        await actions.propose(widget.id, widget.forUserId!, point!);
      } else {
        await actions.choose(widget.id, point);
      }
      messenger.showSnackBar(SnackBar(content: Text(done)));
      if (router.canPop()) router.pop();
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
    final previewState = ref.watch(ridePreviewProvider(widget.id));
    final myId = ref.watch(meProvider.select((me) => me.value?.id));
    final preview = previewState.value;
    if (preview == null) {
      return UmPage(
        appBar: AppBar(),
        children: [
          if (previewState case AsyncError(:final error)) ...[
            UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
            const SizedBox(height: UmSpace.s3),
            UmButton(
              label: l10n.retry,
              variant: UmButtonVariant.ghost,
              onPressed: () => ref.invalidate(ridePreviewProvider(widget.id)),
            ),
          ] else
            Semantics(
              label: l10n.loading,
              child: LinearProgressIndicator(color: c.brand),
            ),
        ],
      );
    }

    final target = widget.forUserId ?? myId;
    final chosen = preview.chosenBy(target);
    if (!_initialised) {
      _initialised = true;
      // Conducteur : son ancienne proposition, sinon le point du passager. Passager : son point,
      // sinon sa prise en charge actuelle.
      final start = (_proposing ? preview.proposedTo(target) : null) ?? chosen;
      if (start != null) {
        _pin = LatLng(start.lat, start.lon);
        _label.text = start.label;
      } else if (preview.me case (final lat, final lon) when !_proposing) {
        _pin = LatLng(lat, lon);
      }
    }
    final label = _label.text.trim();
    final points = [
      for (final (lat, lon) in preview.route) (lat, lon),
      ?preview.me,
      if (_pin case final pin?) (pin.latitude, pin.longitude),
    ];
    final spots = ref.watch(meetingSpotsProvider(boundsAround(points))).value ?? const [];

    return UmPage(
      appBar: AppBar(),
      title: _proposing
          ? l10n.meetingPointProposeTitle(widget.forName ?? '')
          : l10n.meetingPointTitle,
      intro: _proposing ? l10n.meetingPointProposeIntro : l10n.meetingPointIntro,
      footer: [
        UmButton(
          label: _proposing ? l10n.meetingPointPropose : l10n.meetingPointSave,
          expand: true,
          loading: _busy,
          onPressed: label.isEmpty || _pin == null
              ? null
              : () => _save(
                  MeetingPoint(label: label, lat: _pin!.latitude, lon: _pin!.longitude),
                  _proposing ? l10n.meetingPointProposed : l10n.meetingPointSaved,
                ),
        ),
        if (!_proposing && chosen != null)
          UmButton(
            label: l10n.meetingPointReset,
            variant: UmButtonVariant.ghost,
            expand: true,
            onPressed: _busy ? null : () => _save(null, l10n.meetingPointResetDone),
          ),
      ],
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(UmRadius.md),
          child: SizedBox(
            height: math.max(UmSize.mapHeight, MediaQuery.sizeOf(context).height * 0.45),
            child: RideMap(
              // Le trajet reste visible pendant le choix.
              route: preview.route,
              dashed: preview.estimated,
              stops: [
                RideStop(
                  order: 0,
                  kind: StopKind.campus,
                  label: preview.campusName,
                  lat: preview.campus.$1,
                  lon: preview.campus.$2,
                  isMeetingPoint: false,
                ),
              ],
              spots: spots,
              onSpotTap: _pickSpot,
              pin: _pin,
              semanticLabel: l10n.meetingPointMapLabel,
              onTap: (point) => _place(point, l10n.meetingPointOnMap),
            ),
          ),
        ),
        const SizedBox(height: UmSpace.s3),
        Wrap(
          spacing: UmSpace.s4,
          runSpacing: UmSpace.s2,
          children: [
            _Legend(
              badge: const SpotBadge(spot: MeetingSpot(kind: SpotKind.parking, lat: 0, lon: 0)),
              text: l10n.spotParking,
            ),
            _Legend(
              badge: const SpotBadge(spot: MeetingSpot(kind: SpotKind.carpool, lat: 0, lon: 0)),
              text: l10n.spotCarpool,
            ),
          ],
        ),
        const SizedBox(height: UmSpace.s4),
        UmField(
          label: l10n.meetingPointLabel,
          placeholder: l10n.meetingPointHint,
          controller: _label,
          onChanged: (_) => setState(() => _autoLabel = false),
        ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.badge, required this.text});

  final Widget badge;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: UmSize.tapTarget * 0.75, child: badge),
          const SizedBox(width: UmSpace.s1),
          Text(text, style: UmText.bodySm.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}

/// Zone à charger autour des points (tracé, prise en charge, point choisi), avec une marge
/// d'environ 1 km, bornée à ce que le serveur accepte et arrondie (cache des lieux).
MapBounds boundsAround(List<(double, double)> points) {
  if (points.isEmpty) {
    return (south: 45.89, west: 6.10, north: 45.94, east: 6.18); // campus d'Annecy
  }
  const margin = 0.01;
  const maxSpan = 0.24;
  var south = points.map((p) => p.$1).reduce(math.min) - margin;
  var north = points.map((p) => p.$1).reduce(math.max) + margin;
  var west = points.map((p) => p.$2).reduce(math.min) - margin;
  var east = points.map((p) => p.$2).reduce(math.max) + margin;
  double clampSpan(double low, double high, void Function(double, double) set) {
    final span = high - low;
    if (span <= maxSpan) return span;
    final middle = (low + high) / 2;
    set(middle - maxSpan / 2, middle + maxSpan / 2);
    return maxSpan;
  }

  clampSpan(south, north, (a, b) => (south, north) = (a, b));
  clampSpan(west, east, (a, b) => (west, east) = (a, b));
  double round(double v) => (v * 100).roundToDouble() / 100;
  return (south: round(south), west: round(west), north: round(north), east: round(east));
}
