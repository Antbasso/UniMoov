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

/// Point de rendez-vous du passager (cahier §14) : remplace son adresse auprès du
/// conducteur. Le serveur vérifie qu'il reste proche du domicile.
class MeetingPointScreen extends ConsumerStatefulWidget {
  const MeetingPointScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<MeetingPointScreen> createState() => _MeetingPointScreenState();
}

class _MeetingPointScreenState extends ConsumerState<MeetingPointScreen> {
  final _label = TextEditingController();
  LatLng? _pin;
  bool _initialised = false;
  bool _busy = false;
  String? _errorCode;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save(MeetingPoint? point, String done) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(rideProvider(widget.id).notifier).setMeetingPoint(point);
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
    final rideState = ref.watch(rideProvider(widget.id));
    final myId = ref.watch(meProvider.select((me) => me.value?.id));
    final myStop = rideState.value?.stopOf(myId);
    if (myStop == null) {
      return UmPage(
        appBar: AppBar(),
        children: [
          if (rideState case AsyncError(:final error)) ...[
            UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
            const SizedBox(height: UmSpace.s3),
            UmButton(
              label: l10n.retry,
              variant: UmButtonVariant.ghost,
              onPressed: () => ref.invalidate(rideProvider(widget.id)),
            ),
          ] else if (rideState.hasValue)
            // Trajet chargé mais sans arrêt à moi : rien à placer.
            Text(l10n.errorForbidden, style: UmText.body.copyWith(color: c.inkMuted))
          else
            Semantics(
              label: l10n.loading,
              child: LinearProgressIndicator(color: c.brand),
            ),
        ],
      );
    }
    if (!_initialised) {
      _initialised = true;
      _pin = LatLng(myStop.lat, myStop.lon);
      if (myStop.isMeetingPoint) _label.text = myStop.label;
    }
    final label = _label.text.trim();

    return UmPage(
      appBar: AppBar(),
      title: l10n.meetingPointTitle,
      intro: l10n.meetingPointIntro,
      footer: [
        UmButton(
          label: l10n.meetingPointSave,
          expand: true,
          loading: _busy,
          onPressed: label.isEmpty || _pin == null
              ? null
              : () => _save(
                  MeetingPoint(label: label, lat: _pin!.latitude, lon: _pin!.longitude),
                  l10n.meetingPointSaved,
                ),
        ),
        if (myStop.isMeetingPoint)
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
            height: UmSize.mapHeight,
            child: RideMap(
              stops: [myStop],
              route: const [],
              pin: _pin,
              semanticLabel: l10n.meetingPointMapLabel,
              onTap: (point) => setState(() => _pin = point),
            ),
          ),
        ),
        const SizedBox(height: UmSpace.s5),
        UmField(
          label: l10n.meetingPointLabel,
          placeholder: l10n.meetingPointHint,
          controller: _label,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorCode != null) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
        ],
      ],
    );
  }
}
