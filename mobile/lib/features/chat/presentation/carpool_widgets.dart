import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/clock.dart';

import 'package:go_router/go_router.dart';

import '../../../core/router/redirect.dart';
import '../../profile/presentation/me_controller.dart';
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
  late DateTime _day = () {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day + 1);
  }();
  bool _toCampus = true;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _withReturn = false;
  TimeOfDay _returnTime = const TimeOfDay(hour: 17, minute: 0);
  bool _busy = false;
  String? _errorCode;

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<TimeOfDay?> _pick(TimeOfDay initial) => showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  /// Publie l'aller (ou le trajet choisi), puis le retour s'il est programmé.
  Future<void> _publish({String? existingRideId}) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final controller = ref.read(conversationProvider(widget.conversationId).notifier);
    try {
      if (existingRideId != null) {
        await controller.postCarpool(rideId: existingRideId);
      } else {
        await controller.postCarpool(
          day: _day,
          toCampus: _toCampus,
          time: _hhmm(_time),
          create: _driving,
        );
        if (_withReturn && _toCampus) {
          await controller.postCarpool(
            day: _day,
            toCampus: false,
            time: _hhmm(_returnTime),
            create: _driving,
          );
        }
      }
      // Trajets créés : ils apparaissent dans la semaine.
      ref.invalidate(weekProposalsProvider);
      if (mounted) Navigator.of(context).pop();
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
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final canDrive = ref.watch(meProvider).value?.vehicle != null;
    final driving = _driving && canDrive;
    // Mes trajets déjà prévus comme conducteur, cette semaine et la suivante.
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

    Widget timeButton(String label, TimeOfDay value, ValueChanged<TimeOfDay> onPicked) => UmButton(
      label: '$label : ${value.hour} h ${value.minute.toString().padLeft(2, '0')}',
      icon: Icons.schedule_rounded,
      variant: UmButtonVariant.secondary,
      expand: true,
      onPressed: () async {
        final picked = await _pick(value);
        if (picked != null) setState(() => onPicked(picked));
      },
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          UmSpace.s6,
          0,
          UmSpace.s6,
          UmSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.carpoolTitle, style: UmText.h2.copyWith(color: c.ink)),
            ),
            const SizedBox(height: UmSpace.s3),
            if (canDrive)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.directions_car_rounded),
                    label: Text(l10n.carpoolIDrive),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.airline_seat_recline_normal_rounded),
                    label: Text(l10n.carpoolILook),
                  ),
                ],
                selected: {driving},
                onSelectionChanged: (v) => setState(() => _driving = v.first),
              ),
            const SizedBox(height: UmSpace.s3),
            UmCalendar(
              first: today,
              last: today.add(const Duration(days: 13)),
              selected: _day,
              onSelected: (day) => setState(() => _day = day),
            ),
            const SizedBox(height: UmSpace.s3),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(l10n.carpoolToCampus)),
                ButtonSegment(value: false, label: Text(l10n.carpoolFromCampus)),
              ],
              selected: {_toCampus},
              onSelectionChanged: (v) => setState(() {
                _toCampus = v.first;
                _time = _toCampus
                    ? const TimeOfDay(hour: 8, minute: 0)
                    : const TimeOfDay(hour: 17, minute: 0);
              }),
            ),
            const SizedBox(height: UmSpace.s3),
            timeButton(
              _toCampus ? l10n.carpoolArriveAt : l10n.carpoolLeaveAt,
              _time,
              (t) => _time = t,
            ),
            if (_toCampus) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.carpoolWithReturn),
                value: _withReturn,
                onChanged: (on) => setState(() => _withReturn = on),
              ),
              if (_withReturn)
                timeButton(l10n.carpoolReturnAt, _returnTime, (t) => _returnTime = t),
            ],
            const SizedBox(height: UmSpace.s4),
            UmButton(
              label: driving ? l10n.carpoolPublishDrive : l10n.carpoolAsk,
              expand: true,
              loading: _busy,
              onPressed: () => _publish(),
            ),
            if (_errorCode != null) ...[
              const SizedBox(height: UmSpace.s3),
              UmErrorText(apiErrorMessage(l10n, _errorCode)),
            ],
            if (driving && rides.isNotEmpty) ...[
              const SizedBox(height: UmSpace.s5),
              Text(l10n.carpoolExisting, style: UmText.label.copyWith(color: c.inkMuted)),
              for (final p in rides)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.directions_car_rounded, color: c.brandStrong),
                  title: Text(
                    '${tripTitle(l10n, p.direction, p.day)} · ${formatTime(p.time, l10n.localeName)}',
                  ),
                  subtitle: Text(l10n.carpoolSeats(p.seatsLeft)),
                  trailing: Icon(Icons.send_rounded, color: c.brandStrong),
                  onTap: _busy || p.seatsLeft <= 0 ? null : () => _publish(existingRideId: p.id),
                ),
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
    final rideId = carpool.rideFor(widget.myId, mine: widget.mine);
    final canAccept = !widget.mine && !past && !joinedMe;
    final heading = carpool.isOffer ? l10n.carpoolOffer : l10n.carpoolRequest;

    // Mon trajet (proposé, rejoint ou pris en charge) : la carte l'ouvre d'un toucher.
    void open() => context.push(AppRoutes.proposal(isoWeekOf(carpool.day), rideId!));
    return Align(
      alignment: widget.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: InkWell(
          borderRadius: BorderRadius.circular(UmRadius.md),
          onTap: rideId == null ? null : open,
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
                          Expanded(
                            child: Text(
                              widget.sender == null ? heading : '$heading · ${widget.sender}',
                              style: UmText.label.copyWith(color: c.brandStrong),
                            ),
                          ),
                          if (rideId != null)
                            Icon(Icons.chevron_right_rounded, color: c.brandStrong),
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
                                l10n.carpoolJoined(
                                  carpool.joined.map((j) => j.firstName).join(', '),
                                ),
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
      ),
    );
  }
}
