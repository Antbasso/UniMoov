import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../theme/um_theme.dart';
import 'um_button.dart';
import 'um_chip.dart';

enum UmRideStatus { proposed, confirmed, cancelled }

/// Carte de trajet (docs/design-system/components/RideCard.md). Une seule action.
class UmRideCard extends StatelessWidget {
  const UmRideCard({
    super.key,
    required this.from,
    required this.to,
    required this.time,
    required this.driverFirstName,
    required this.seatsLeft,
    required this.priceCents,
    required this.status,
    this.actionLabel,
    this.onAction,
  });

  final String from;
  final String to;
  final String time;
  final String driverFirstName;
  final int seatsLeft;

  /// Montant en centimes (entier, jamais de flottant).
  final int priceCents;
  final UmRideStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;

  static String formatPrice(int cents, String locale) =>
      NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 2).format(cents / 100);

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final l10n = AppLocalizations.of(context);
    final price = formatPrice(priceCents, l10n.localeName);
    final chip = switch (status) {
      UmRideStatus.proposed => UmChip(label: l10n.rideStatusProposed, icon: Icons.schedule_rounded),
      UmRideStatus.confirmed => UmChip(
        label: l10n.rideStatusConfirmed,
        icon: Icons.check_circle_outline_rounded,
        tone: UmChipTone.success,
      ),
      UmRideStatus.cancelled => UmChip(
        label: l10n.rideStatusCancelled,
        icon: Icons.cancel_outlined,
        tone: UmChipTone.danger,
      ),
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: UmSize.rideCardMaxWidth),
      padding: const EdgeInsets.all(UmSpace.s4),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.md),
        boxShadow: context.umShadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stop(label: from, semantic: l10n.rideFrom(from), isEnd: false),
                    const SizedBox(height: UmSpace.s1),
                    _Stop(label: to, semantic: l10n.rideTo(to), isEnd: true),
                    const SizedBox(height: UmSpace.s1),
                    Text(
                      '${l10n.rideMeta(time, driverFirstName)} · ${l10n.rideSeats(seatsLeft)}',
                      style: UmText.bodySm.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UmSpace.s4),
              Semantics(
                label: l10n.ridePriceLabel(price),
                excludeSemantics: true,
                child: Text(price, style: UmText.h2.copyWith(color: c.brandStrong)),
              ),
            ],
          ),
          const SizedBox(height: UmSpace.s3),
          Row(
            children: [
              chip,
              const Spacer(),
              if (actionLabel != null) UmButton(label: actionLabel!, onPressed: onAction),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.label, required this.semantic, required this.isEnd});

  final String label;
  final String semantic;
  final bool isEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: UmSize.routeDot,
            height: UmSize.routeDot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnd ? null : c.brand,
              border: isEnd ? Border.all(color: c.brandStrong, width: UmSize.routeRing) : null,
            ),
          ),
          const SizedBox(width: UmSpace.s2),
          Expanded(
            child: Text(
              label,
              style: UmText.body.copyWith(fontWeight: FontWeight.w600, color: c.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
