import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/ride.dart';
import 'rides_controller.dart';

/// Point proposé par le conducteur au passager : l'accepter (il devient son point de
/// rendez-vous) ou garder le sien.
class MeetingOfferCard extends ConsumerStatefulWidget {
  const MeetingOfferCard({
    super.key,
    required this.rideId,
    required this.driverName,
    required this.point,
  });

  final String rideId;
  final String driverName;
  final MeetingPoint point;

  @override
  ConsumerState<MeetingOfferCard> createState() => _MeetingOfferCardState();
}

class _MeetingOfferCardState extends ConsumerState<MeetingOfferCard> {
  bool _busy = false;
  String? _errorCode;

  Future<void> _answer({required bool accept}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref.read(meetingPointActionsProvider).answer(widget.rideId, accept: accept);
      messenger.showSnackBar(
        SnackBar(content: Text(accept ? l10n.meetingPointAccepted : l10n.meetingPointDeclined)),
      );
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
    return UmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.where_to_vote_outlined, color: c.brandStrong),
              const SizedBox(width: UmSpace.s3),
              Expanded(
                child: Text(
                  l10n.meetingPointOffer(widget.driverName, widget.point.label),
                  style: UmText.body.copyWith(color: c.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: UmSpace.s3),
          OverflowBar(
            spacing: UmSpace.s2,
            overflowSpacing: UmSpace.s2,
            alignment: MainAxisAlignment.end,
            children: [
              UmButton(
                label: l10n.meetingPointDecline,
                variant: UmButtonVariant.ghost,
                onPressed: _busy ? null : () => _answer(accept: false),
              ),
              UmButton(
                label: l10n.meetingPointAccept,
                loading: _busy,
                onPressed: () => _answer(accept: true),
              ),
            ],
          ),
          if (_errorCode != null) ...[
            const SizedBox(height: UmSpace.s2),
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
          ],
        ],
      ),
    );
  }
}

/// Passager, avant d'accepter (ou après) : où le conducteur le prendra, la proposition du
/// conducteur s'il en a fait une, et le choix d'un autre point sur la carte.
class PassengerMeetingSection extends ConsumerWidget {
  const PassengerMeetingSection({
    super.key,
    required this.rideId,
    required this.myId,
    required this.driverName,
  });

  final String rideId;
  final String? myId;
  final String driverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final preview = ref.watch(ridePreviewProvider(rideId)).value;
    if (preview == null) return const SizedBox.shrink();
    final chosen = preview.chosenBy(myId);
    final offer = preview.proposedTo(myId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UmSectionTitle(l10n.rideMeetingPoint),
        const SizedBox(height: UmSpace.s2),
        if (offer != null) ...[
          MeetingOfferCard(rideId: rideId, driverName: driverName, point: offer),
          const SizedBox(height: UmSpace.s3),
        ],
        Row(
          children: [
            Icon(chosen == null ? Icons.home_outlined : Icons.place_outlined, color: c.brandStrong),
            const SizedBox(width: UmSpace.s2),
            Expanded(
              child: Text(
                chosen == null ? l10n.meetingPointAtHome : l10n.meetingPointMine(chosen.label),
                style: UmText.body.copyWith(color: c.ink),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: UmButton(
            label: chosen == null ? l10n.meetingPointChoose : l10n.rideChangeMeetingPoint,
            icon: Icons.map_outlined,
            variant: UmButtonVariant.ghost,
            onPressed: () => context.push(AppRoutes.rideMeetingPoint(rideId)),
          ),
        ),
      ],
    );
  }
}

/// Conducteur : où il retrouvera ce passager (point choisi, ou sa proposition en attente).
String? driverMeetingText(AppLocalizations l10n, RidePreview? preview, String userId) {
  final proposed = preview?.proposedTo(userId);
  if (proposed != null) return l10n.meetingPointPending(proposed.label);
  final chosen = preview?.chosenBy(userId);
  return chosen == null ? null : l10n.meetingPointMine(chosen.label);
}
