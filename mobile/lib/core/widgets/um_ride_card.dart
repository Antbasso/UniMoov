import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../theme/um_theme.dart';
import 'um_button.dart';
import 'um_chip.dart';

/// `waiting` : tu as accepté, l'autre partie pas encore (confirmation à deux).
enum UmRideStatus { proposed, waiting, confirmed, inProgress, completed, cancelled }

/// Rôle de la personne sur le trajet, affiché en tête de carte (icône et texte, jamais la
/// couleur seule).
enum UmRideRole { driver, passenger }

/// Carte de trajet (docs/design-system/components/RideCard.md). Une seule action.
class UmRideCard extends StatelessWidget {
  const UmRideCard({
    super.key,
    required this.from,
    required this.to,
    required this.time,
    required this.driverFirstName,
    required this.seatsLeft,
    this.priceCents,
    required this.status,
    this.metaText,
    this.actionLabel,
    this.onAction,
    this.actionVariant = UmButtonVariant.primary,
    this.role,
    this.live = false,
  });

  /// Rôle mis en avant avec l'heure en grand (liste de la semaine).
  final UmRideRole? role;

  /// Trajet en cours : contour qui pulse (fixe si les animations sont réduites).
  final bool live;

  final String from;
  final String to;
  final String time;
  final String driverFirstName;
  final int seatsLeft;

  /// Montant en centimes (entier, jamais de flottant) ; absent tant qu'il n'est pas calculé.
  final int? priceCents;

  /// Remplace la ligne « horaire · avec … · places » (ex. côté conducteur).
  final String? metaText;
  final UmRideStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Dans une liste de cartes, `secondary` : un seul bouton principal par écran.
  final UmButtonVariant actionVariant;

  static String formatPrice(int cents, String locale) =>
      NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 2).format(cents / 100);

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final l10n = AppLocalizations.of(context);
    final price = priceCents == null ? null : formatPrice(priceCents!, l10n.localeName);
    final chip = switch (status) {
      UmRideStatus.proposed => UmChip(label: l10n.rideStatusProposed, icon: Icons.schedule_rounded),
      UmRideStatus.waiting => UmChip(
        label: l10n.rideStatusWaiting,
        icon: Icons.hourglass_empty_rounded,
      ),
      UmRideStatus.confirmed => UmChip(
        label: l10n.rideStatusConfirmed,
        icon: Icons.check_circle_outline_rounded,
        tone: UmChipTone.success,
      ),
      UmRideStatus.inProgress => UmChip(
        label: l10n.rideInProgress,
        icon: Icons.near_me_outlined,
        tone: UmChipTone.success,
      ),
      UmRideStatus.completed => UmChip(label: l10n.rideCompleted, icon: Icons.flag_outlined),
      UmRideStatus.cancelled => UmChip(
        label: l10n.rideStatusCancelled,
        icon: Icons.cancel_outlined,
        tone: UmChipTone.danger,
      ),
    };

    final role = this.role;
    final card = Container(
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
          if (role != null) ...[
            // Texte agrandi : l'heure passe sous le rôle plutôt que de déborder.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: UmSpace.s3,
              runSpacing: UmSpace.s2,
              children: [
                _RoleBadge(role: role),
                Text(time, style: UmText.h2.copyWith(color: c.ink)),
              ],
            ),
            const SizedBox(height: UmSpace.s3),
          ],
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
                      metaText ??
                          (role != null
                              ? '${l10n.rideWith(driverFirstName)} · ${l10n.rideSeats(seatsLeft)}'
                              : '${l10n.rideMeta(time, driverFirstName)} · '
                                    '${l10n.rideSeats(seatsLeft)}'),
                      style: UmText.bodySm.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: UmSpace.s4),
                Semantics(
                  label: l10n.ridePriceLabel(price),
                  excludeSemantics: true,
                  child: Text(price, style: UmText.h2.copyWith(color: c.brandStrong)),
                ),
              ],
            ],
          ),
          const SizedBox(height: UmSpace.s3),
          Row(
            children: [
              chip,
              const Spacer(),
              if (actionLabel != null)
                UmButton(label: actionLabel!, variant: actionVariant, onPressed: onAction),
            ],
          ),
        ],
      ),
    );
    return live ? _LivePulse(child: card) : card;
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UmRideRole role;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final l10n = AppLocalizations.of(context);
    final driver = role == UmRideRole.driver;
    final fg = driver ? c.onBrand : c.brandStrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3, vertical: UmSpace.s1),
      decoration: BoxDecoration(
        color: driver ? c.brandStrong : c.lavender,
        borderRadius: BorderRadius.circular(UmRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            driver ? Icons.directions_car_rounded : Icons.airline_seat_recline_normal_rounded,
            size: UmSize.iconMd,
            color: fg,
          ),
          const SizedBox(width: UmSpace.s2),
          Flexible(
            child: Text(
              driver ? l10n.badgeDriver : l10n.badgePassenger,
              style: UmText.button.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contour pulsé du trajet en cours.
class _LivePulse extends StatefulWidget {
  const _LivePulse({required this.child});

  final Widget child;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UmRadius.md),
          border: Border.all(
            color: Color.lerp(c.lavender, c.brand, _controller.value)!,
            width: UmSize.routeRing,
          ),
        ),
        child: child,
      ),
      child: widget.child,
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
