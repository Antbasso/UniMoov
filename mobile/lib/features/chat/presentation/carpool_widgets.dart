import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../proposals/domain/proposal.dart';
import '../../proposals/presentation/formatting.dart';
import '../../proposals/presentation/proposals_controller.dart';
import '../../rides/presentation/trip_widgets.dart';
import '../../wallet/presentation/insufficient_funds_dialog.dart';
import '../domain/chat.dart';
import 'chat_controller.dart';

/// Proposer un covoiturage dans une conversation : un trajet que je conduis, ou une demande
/// pour un jour et un sens.
Future<void> showCarpoolSheet(BuildContext context, String conversationId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CarpoolSheet(conversationId: conversationId),
    );

class _CarpoolSheet extends ConsumerStatefulWidget {
  const _CarpoolSheet({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_CarpoolSheet> createState() => _CarpoolSheetState();
}

class _CarpoolSheetState extends ConsumerState<_CarpoolSheet> {
  bool _driving = true;
  DateTime? _day;
  bool _toCampus = true;
  bool _busy = false;
  String? _errorCode;

  Future<void> _post({String? rideId}) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref
          .read(conversationProvider(widget.conversationId).notifier)
          .postCarpool(rideId: rideId, day: _day, toCampus: _toCampus);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDay() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 21)),
      initialDate: _day ?? today.add(const Duration(days: 1)),
    );
    if (day != null) setState(() => _day = day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final now = ref.watch(clockProvider)();
    // Mes trajets à venir comme conducteur engagé, cette semaine et la suivante.
    final rides =
        [
          for (final week in [isoWeekOf(now), isoWeekOf(now.add(const Duration(days: 7)))])
            ...?ref.watch(weekProposalsProvider(week)).value,
        ].where(
          (p) =>
              p.isDriver &&
              p.myStatus == 'accepted' &&
              (p.rideStatus == 'proposed' || p.rideStatus == 'confirmed') &&
              p.time.isAfter(now),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.carpoolTitle, style: UmText.h2.copyWith(color: c.ink)),
            ),
            const SizedBox(height: UmSpace.s3),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(l10n.carpoolIDrive)),
                ButtonSegment(value: false, label: Text(l10n.carpoolILook)),
              ],
              selected: {_driving},
              onSelectionChanged: (v) => setState(() => _driving = v.first),
            ),
            const SizedBox(height: UmSpace.s4),
            if (_driving) ...[
              if (rides.isEmpty)
                Text(l10n.carpoolNoRide, style: UmText.body.copyWith(color: c.inkMuted))
              else
                for (final p in rides)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.directions_car_rounded, color: c.brandStrong),
                    title: Text(
                      '${tripTitle(l10n, p.direction, p.day)} · ${formatTime(p.time, l10n.localeName)}',
                    ),
                    subtitle: Text(l10n.carpoolSeats(p.seatsLeft)),
                    trailing: Icon(Icons.send_rounded, color: c.brandStrong),
                    onTap: _busy || p.seatsLeft <= 0 ? null : () => _post(rideId: p.id),
                  ),
            ] else ...[
              UmButton(
                label: _day == null ? l10n.carpoolPickDay : formatDay(_day!, l10n.localeName),
                icon: Icons.event_rounded,
                variant: UmButtonVariant.secondary,
                expand: true,
                onPressed: _pickDay,
              ),
              const SizedBox(height: UmSpace.s3),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(l10n.carpoolToCampus)),
                  ButtonSegment(value: false, label: Text(l10n.carpoolFromCampus)),
                ],
                selected: {_toCampus},
                onSelectionChanged: (v) => setState(() => _toCampus = v.first),
              ),
              const SizedBox(height: UmSpace.s4),
              UmButton(
                label: l10n.carpoolAsk,
                expand: true,
                loading: _busy,
                onPressed: _day == null ? null : () => _post(),
              ),
            ],
            if (_errorCode != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, _errorCode)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Proposition de covoiturage dans le fil : qui, quel trajet, qui est monté, et le bouton pour
/// accepter (« Je monte » sur une offre, « Je te prends » sur une demande).
class CarpoolCard extends ConsumerStatefulWidget {
  const CarpoolCard({
    super.key,
    required this.message,
    required this.mine,
    required this.myId,
    this.sender,
  });

  final ChatMessage message;
  final bool mine;
  final String? myId;
  final String? sender;

  @override
  ConsumerState<CarpoolCard> createState() => _CarpoolCardState();
}

class _CarpoolCardState extends ConsumerState<CarpoolCard> {
  bool _busy = false;

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(conversationProvider(widget.message.conversationId).notifier)
          .acceptCarpool(widget.message.id);
      ref.invalidate(weekProposalsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.carpoolDone)));
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'insufficient_funds') {
        await showInsufficientFunds(context);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(l10n, error.code))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final carpool = widget.message.carpool!;
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final past = carpool.day.isBefore(today);
    final title = tripTitle(
      l10n,
      carpool.toCampus ? Direction.toCampus : Direction.fromCampus,
      carpool.day,
    );
    final when = carpool.time == null
        ? title
        : '$title · ${formatTime(carpool.time!, l10n.localeName)}';
    final joinedMe = carpool.joined.any((j) => j.userId == widget.myId);
    final canAccept = !widget.mine && !past && !joinedMe;
    final heading = carpool.isOffer ? l10n.carpoolOffer : l10n.carpoolRequest;

    return Align(
      alignment: widget.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Container(
          margin: const EdgeInsets.only(bottom: UmSpace.s2),
          padding: const EdgeInsets.all(UmSpace.s3),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(UmRadius.md),
            border: Border.all(color: c.brand, width: UmSize.routeRing),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                label: [
                  heading,
                  ?widget.sender,
                  when,
                  if (carpool.joined.isNotEmpty)
                    l10n.carpoolJoined(carpool.joined.map((j) => j.firstName).join(', ')),
                ].join(', '),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          carpool.isOffer
                              ? Icons.directions_car_rounded
                              : Icons.front_hand_outlined,
                          color: c.brandStrong,
                        ),
                        const SizedBox(width: UmSpace.s2),
                        Flexible(
                          child: Text(
                            widget.sender == null ? heading : '$heading · ${widget.sender}',
                            style: UmText.label.copyWith(color: c.brandStrong),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UmSpace.s1),
                    Text(
                      when,
                      style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                    ),
                    if (carpool.joined.isNotEmpty) ...[
                      const SizedBox(height: UmSpace.s1),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: UmSize.iconSm, color: c.success),
                          const SizedBox(width: UmSpace.s1),
                          Flexible(
                            child: Text(
                              l10n.carpoolJoined(carpool.joined.map((j) => j.firstName).join(', ')),
                              style: UmText.bodySm.copyWith(color: c.ink),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (canAccept) ...[
                const SizedBox(height: UmSpace.s2),
                UmButton(
                  label: carpool.isOffer ? l10n.carpoolJoin : l10n.carpoolTake,
                  loading: _busy,
                  onPressed: _accept,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
