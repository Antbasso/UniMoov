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
import '../domain/trust.dart';
import 'trust_controller.dart';

/// Score sur 5, avec une décimale, comme sur les propositions.
String formatScore(double score) => (score * 5).toStringAsFixed(1).replaceAll('.', ',');

/// « Ma fiabilité » (cahier §7) : le score, ce qui le compose, et les pénalités récentes
/// avec un lien pour les contester (cahier §10).
class ReliabilityScreen extends ConsumerWidget {
  const ReliabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final reliability = ref.watch(reliabilityProvider);

    return switch (reliability) {
      AsyncError(:final error) => UmPage(
        appBar: AppBar(),
        title: l10n.reliabilityTitle,
        children: [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          const SizedBox(height: UmSpace.s3),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(reliabilityProvider),
          ),
        ],
      ),
      AsyncValue(:final value?) => UmPage(
        appBar: AppBar(),
        title: l10n.reliabilityTitle,
        intro: l10n.reliabilityIntro(value.windowDays),
        children: [
          UmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label:
                      '${l10n.reliabilityScoreLabel} : ${l10n.reliabilityScore(formatScore(value.score))}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reliabilityScoreLabel,
                        style: UmText.label.copyWith(color: c.inkMuted),
                      ),
                      Text(
                        l10n.reliabilityScore(formatScore(value.score)),
                        style: UmText.h1.copyWith(color: c.brandStrong),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: UmSpace.s3),
                for (final line in [
                  l10n.reliabilityCompleted(value.completedRides),
                  l10n.reliabilityCancellations(value.cancellations),
                  l10n.reliabilityNoShows(value.noShows),
                  if (value.averageStars case final avg?)
                    l10n.reliabilityRatings(
                      value.ratingsCount,
                      avg.toStringAsFixed(1).replaceAll('.', ','),
                    )
                  else
                    l10n.reliabilityNoRatings,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: UmSpace.s1),
                    child: Text(line, style: UmText.body.copyWith(color: c.ink)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: UmSpace.s5),
          Semantics(
            header: true,
            child: Text(l10n.reliabilityEventsTitle, style: UmText.h3.copyWith(color: c.ink)),
          ),
          const SizedBox(height: UmSpace.s3),
          if (value.events.isEmpty)
            Text(
              l10n.reliabilityEmpty(value.windowDays),
              style: UmText.body.copyWith(color: c.inkMuted),
            )
          else
            for (final event in value.events) _EventRow(event: event),
        ],
      ),
      _ => UmPage(
        appBar: AppBar(),
        title: l10n.reliabilityTitle,
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final ReliabilityEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final title = switch (event.kind) {
      ReliabilityEventKind.cancelEarly => l10n.eventCancelEarly,
      ReliabilityEventKind.cancelMedium => l10n.eventCancelMedium,
      ReliabilityEventKind.cancelLate => l10n.eventCancelLate,
      ReliabilityEventKind.noShow => l10n.eventNoShow,
      ReliabilityEventKind.correction => l10n.eventCorrection,
    };
    final day = event.day;
    final reason = event.disputeReason;
    final rideId = event.rideId;
    final contestable = reason != null && rideId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s3),
      child: UmCard(
        title: title,
        body: day == null ? null : l10n.eventRideOn(formatDayInline(day, l10n.localeName)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.kind == ReliabilityEventKind.correction)
              UmChip(
                label: l10n.disputeCorrected,
                icon: Icons.check_circle_outline_rounded,
                tone: UmChipTone.success,
              )
            else if (contestable)
              UmButton(
                label: l10n.contest,
                variant: UmButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.dispute(rideId, reason: reason)),
              )
            else
              Text(l10n.eventContestClosed, style: UmText.caption.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}
