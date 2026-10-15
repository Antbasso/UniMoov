import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/proposal.dart';
import 'formatting.dart';
import 'proposals_controller.dart';

/// Liste de voitures où monter (« voir d'autres » et résultats de recherche).
class JoinableList extends ConsumerStatefulWidget {
  const JoinableList({super.key, required this.rides});

  final List<JoinableRide> rides;

  @override
  ConsumerState<JoinableList> createState() => _JoinableListState();
}

class _JoinableListState extends ConsumerState<JoinableList> {
  String? _busyId;
  String? _errorCode;

  Future<void> _join(JoinableRide ride) async {
    setState(() {
      _busyId = ride.rideId;
      _errorCode = null;
    });
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(weekProposalsProvider(isoWeekOf(ride.day)).notifier).join(ride.rideId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.joined)));
      router.go(AppRoutes.home);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorCode != null) ...[
          UmErrorText(apiErrorMessage(l10n, _errorCode)),
          const SizedBox(height: UmSpace.s3),
        ],
        for (final ride in widget.rides)
          Padding(
            padding: const EdgeInsets.only(bottom: UmSpace.s3),
            child: () {
              final (from, to) = endpoints(l10n, ride.direction, driver: false);
              final time = formatTime(ride.time, l10n.localeName);
              return UmRideCard(
                from: from,
                to: to,
                time: time,
                driverFirstName: ride.driver.firstName,
                seatsLeft: ride.seatsLeft,
                status: UmRideStatus.proposed,
                metaText:
                    '${l10n.rideMeta(time, ride.driver.firstName)} · ${l10n.personDetails(ride.driver.scoreOutOfFive, ride.driver.detourMinutes)}',
                actionLabel: l10n.choose,
                actionVariant: UmButtonVariant.secondary,
                onAction: _busyId == null ? () => _join(ride) : null,
              );
            }(),
          ),
      ],
    );
  }
}

class AlternativesScreen extends ConsumerWidget {
  const AlternativesScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final rides = ref.watch(alternativesProvider(id));
    return UmPage(
      appBar: AppBar(),
      title: l10n.alternativesTitle,
      children: switch (rides) {
        AsyncData(:final value) when value.isEmpty => [
          Text(l10n.alternativesEmpty, style: UmText.body.copyWith(color: c.inkMuted)),
        ],
        AsyncData(:final value) => [JoinableList(rides: value)],
        AsyncError(:final error) => [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(alternativesProvider(id)),
          ),
        ],
        _ => [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand),
          ),
        ],
      },
    );
  }
}
