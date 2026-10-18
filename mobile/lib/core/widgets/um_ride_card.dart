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

/// Carte de trajet (docs/design-system/components/RideCard.md), allégée : l'heure en grand,
/// « départ → arrivée » sur une ligne, un statut. Chaque état a sa teinte : dégradé animé en
/// cours, vert confirmé, lavande à confirmer, grisé terminé ou annulé. Toute la carte s'ouvre
/// au toucher (`onTap`) ; un bouton reste possible (`actionLabel`, ex. « Choisir »).
class UmRideCard extends StatelessWidget {
  const UmRideCard({
    super.key,
    required this.from,
    required this.to,
    required this.time,
    required this.driverFirstName,
    required this.seatsLeft,
    this.priceCents,
    this.priceLabel,
    required this.status,
    this.metaText,
    this.meta = const [],
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.actionVariant = UmButtonVariant.primary,
    this.role,
    this.live = false,
  });

  /// Rôle mis en avant avec l'heure en grand (liste de la semaine).
  final UmRideRole? role;

  /// Trajet en cours : fond en dégradé animé (fixe si les animations sont réduites).
  final bool live;

  final String from;
  final String to;
  final String time;
  final String driverFirstName;
  final int seatsLeft;

  /// Montant en centimes (entier, jamais de flottant) ; absent tant qu'il n'est pas calculé.
  final int? priceCents;

  /// Petit libellé devant le prix (« Tu reçois » côté conducteur) ; sinon le prix seul.
  final String? priceLabel;

  /// Ligne de détail en texte (recherche) ; sinon `meta`, petites icônes et valeurs.
  final String? metaText;
  final List<(IconData, String)> meta;
  final UmRideStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Toucher la carte (ouvre le trajet).
  final VoidCallback? onTap;

  /// Dans une liste de cartes, `secondary` : un seul bouton principal par écran.
  final UmButtonVariant actionVariant;

  static String formatPrice(int cents, String locale) =>
      NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 2).format(cents / 100);

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final l10n = AppLocalizations.of(context);
    final price = priceCents == null ? null : formatPrice(priceCents!, l10n.localeName);
    final onGradient = live;
    final ink = onGradient ? c.onBrand : c.ink;
    final muted = onGradient ? c.onBrand : c.inkMuted;

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
      UmRideStatus.inProgress => _LiveChip(label: l10n.rideStatusLive),
      UmRideStatus.completed => UmChip(label: l10n.rideCompleted, icon: Icons.flag_outlined),
      UmRideStatus.cancelled => UmChip(
        label: l10n.rideStatusCancelled,
        icon: Icons.cancel_outlined,
        tone: UmChipTone.danger,
      ),
    };
    // Teinte du bord gauche : repère l'état d'un coup d'œil (doublée par la puce).
    final accent = switch (status) {
      UmRideStatus.confirmed => c.success,
      UmRideStatus.proposed || UmRideStatus.waiting => c.lavender,
      UmRideStatus.cancelled => c.danger,
      UmRideStatus.inProgress => c.brand,
      UmRideStatus.completed => c.border,
    };

    final role = this.role;
    final metaLine = metaText != null
        ? Text(metaText!, style: UmText.bodySm.copyWith(color: muted))
        : meta.isEmpty
        ? null
        : Wrap(
            spacing: UmSpace.s4,
            runSpacing: UmSpace.s1,
            children: [
              // Icône et texte dans une même phrase : le texte agrandi passe à la ligne.
              for (final (icon, text) in meta)
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: UmSpace.s1),
                          child: Icon(icon, size: UmSize.iconSm, color: muted),
                        ),
                      ),
                      TextSpan(text: text),
                    ],
                  ),
                  style: UmText.bodySm.copyWith(color: muted),
                ),
            ],
          );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(UmSpace.s4, UmSpace.s3, UmSpace.s4, UmSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Texte agrandi : la puce passe sous l'heure plutôt que de déborder.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: UmSpace.s3,
            runSpacing: UmSpace.s2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (role != null) ...[
                    _RoleBadge(role: role, onGradient: onGradient),
                    const SizedBox(width: UmSpace.s3),
                  ],
                  Text(time, style: UmText.h2.copyWith(color: ink)),
                ],
              ),
              chip,
            ],
          ),
          const SizedBox(height: UmSpace.s2),
          Semantics(
            label: '${l10n.rideFrom(from)}, ${l10n.rideTo(to)}',
            excludeSemantics: true,
            // Une seule phrase qui peut passer à la ligne : rien n'est coupé.
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: from),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UmSpace.s2),
                      child: Icon(Icons.arrow_forward_rounded, size: UmSize.iconSm, color: muted),
                    ),
                  ),
                  TextSpan(text: to),
                ],
              ),
              style: UmText.body.copyWith(color: ink),
            ),
          ),
          if (metaLine != null) ...[const SizedBox(height: UmSpace.s1), metaLine],
          if (price != null || actionLabel != null) ...[
            const SizedBox(height: UmSpace.s2),
            Row(
              children: [
                if (price != null)
                  Flexible(
                    child: Semantics(
                      label: priceLabel == null
                          ? l10n.ridePriceLabel(price)
                          : '${priceLabel!} $price',
                      excludeSemantics: true,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (priceLabel != null)
                              TextSpan(
                                text: '${priceLabel!} ',
                                style: UmText.bodySm.copyWith(color: muted),
                              ),
                            TextSpan(
                              text: price,
                              style: UmText.h3.copyWith(color: onGradient ? ink : c.brandStrong),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                if (actionLabel != null)
                  UmButton(label: actionLabel!, variant: actionVariant, onPressed: onAction),
              ],
            ),
          ],
        ],
      ),
    );

    final faded = status == UmRideStatus.cancelled || status == UmRideStatus.completed;
    final shape = BorderRadius.circular(UmRadius.md);
    Widget card = Container(
      constraints: const BoxConstraints(maxWidth: UmSize.rideCardMaxWidth),
      decoration: BoxDecoration(
        color: live ? null : (faded ? c.surface : c.surfaceRaised),
        borderRadius: shape,
        boxShadow: faded || live ? null : context.umShadowSoft,
        border: faded ? Border.all(color: c.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!live) Container(width: UmSize.rideAccent, color: accent),
            Expanded(child: content),
          ],
        ),
      ),
    );
    if (live) card = _LiveGradient(child: card);
    if (onTap != null) {
      card = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: shape, onTap: onTap, child: card),
      );
    }
    return card;
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.onGradient});

  final UmRideRole role;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final l10n = AppLocalizations.of(context);
    final driver = role == UmRideRole.driver;
    final label = driver ? l10n.badgeDriver : l10n.badgePassenger;
    final (bg, fg) = onGradient
        ? (c.onBrand, c.brandStrong)
        : driver
        ? (c.brandStrong, c.onBrand)
        : (c.lavender, c.brandStrong);
    // Icône seule à l'écran (texte pour les lecteurs d'écran et en info-bulle).
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Container(
          width: UmSize.roleBadge,
          height: UmSize.roleBadge,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(
            driver ? Icons.directions_car_rounded : Icons.airline_seat_recline_normal_rounded,
            size: UmSize.iconSm,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Puce « En cours » sur fond dégradé : blanche, avec un point.
class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3, vertical: UmSpace.s1),
        decoration: BoxDecoration(
          color: c.onBrand,
          borderRadius: BorderRadius.circular(UmRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_rounded, size: UmSize.iconSm, color: c.brandStrong),
            const SizedBox(width: UmSpace.s1),
            Text(label, style: UmText.label.copyWith(color: c.brandStrong)),
          ],
        ),
      ),
    );
  }
}

/// Fond du trajet en cours : dégradé de la marque qui glisse doucement (fixe si les
/// animations sont réduites).
class UmLiveGradient extends StatefulWidget {
  const UmLiveGradient({super.key, required this.child, this.radius = UmRadius.md});

  final Widget child;
  final double radius;

  @override
  State<UmLiveGradient> createState() => _UmLiveGradientState();
}

typedef _LiveGradient = UmLiveGradient;

class _UmLiveGradientState extends State<UmLiveGradient> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
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
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: context.umShadowSoft,
            gradient: LinearGradient(
              begin: Alignment(-1 - t, -1),
              end: Alignment(1 - t, 1),
              colors: [c.brandStrong, c.brand, c.brandStrong],
              tileMode: TileMode.mirror,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
