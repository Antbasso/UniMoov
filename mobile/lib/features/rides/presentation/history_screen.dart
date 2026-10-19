import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../proposals/presentation/formatting.dart';
import '../data/rides_api.dart';
import '../domain/ride.dart';

final historyProvider = FutureProvider.autoDispose<List<HistoryEntry>>(
  (ref) => ref.watch(ridesApiProvider).history(),
  retry: (retryCount, error) => null,
);

/// Historique : trajets terminés, sortis de l'accueil. Une ligne par trajet (date, sens,
/// montant) ; le toucher ouvre le trajet (notation, problème).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final history = ref.watch(historyProvider);

    return UmPage(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      children: switch (history) {
        AsyncData(:final value) when value.isEmpty => [
          Text(l10n.historyEmpty, style: UmText.body.copyWith(color: c.inkMuted)),
        ],
        AsyncData(:final value) => [for (final entry in value) _HistoryRow(entry: entry)],
        AsyncError(:final error) => [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          const SizedBox(height: UmSpace.s2),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(historyProvider),
          ),
        ],
        _ => [
          Semantics(
            label: l10n.loading,
            child: LinearProgressIndicator(color: c.brand, backgroundColor: c.lavender),
          ),
        ],
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final (from, to) = endpoints(l10n, entry.direction, driver: entry.isDriver);
    final amount = entry.amountCents;
    final money = amount == null
        ? null
        : '${entry.isDriver ? '+' : '−'}${UmRideCard.formatPrice(amount, l10n.localeName)}';
    final role = entry.isDriver ? l10n.badgeDriver : l10n.badgePassenger;
    final day = formatDay(entry.day, l10n.localeName);
    final time = formatTime(entry.time, l10n.localeName);
    return Semantics(
      button: true,
      label: [
        day,
        time,
        role,
        '${l10n.rideFrom(from)}, ${l10n.rideTo(to)}',
        if (entry.absent) l10n.historyAbsent,
        ?money,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(UmRadius.sm),
        onTap: () => context.push(AppRoutes.ride(entry.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: UmSpace.s3),
          child: Row(
            children: [
              Icon(
                entry.isDriver
                    ? Icons.directions_car_rounded
                    : Icons.airline_seat_recline_normal_rounded,
                color: c.inkMuted,
              ),
              const SizedBox(width: UmSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$day · $time', style: UmText.body.copyWith(color: c.ink)),
                    Text(
                      [
                        '$from → $to',
                        if (entry.withNames.isNotEmpty) entry.withNames.join(', '),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UmText.bodySm.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UmSpace.s3),
              if (entry.absent)
                UmChip(label: l10n.historyAbsent, icon: Icons.person_off_outlined)
              else if (money != null)
                Text(
                  money,
                  style: UmText.button.copyWith(color: entry.isDriver ? c.success : c.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
