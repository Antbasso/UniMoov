import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../proposals/domain/proposal.dart';
import '../domain/ride.dart';

/// Titre court d'un trajet, pour la barre du haut : « Aller · lun. 19 oct. ».
String tripTitle(AppLocalizations l10n, Direction direction, DateTime day) {
  final date = DateFormat('EEE d MMM', l10n.localeName).format(day);
  return direction == Direction.toCampus ? l10n.tripTitleTo(date) : l10n.tripTitleFrom(date);
}

/// Petite donnée visuelle : une icône et une valeur courte (« ★ 4,5 », « ⏱ +3 min »). Le
/// libellé complet est pour les lecteurs d'écran.
class UmStat extends StatelessWidget {
  const UmStat({super.key, required this.icon, required this.value, required this.semantic});

  final IconData icon;
  final String value;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: UmSize.iconSm, color: c.inkMuted),
          const SizedBox(width: UmSpace.s1),
          Flexible(
            child: Text(value, style: UmText.bodySm.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}

/// Une personne du trajet sur une ligne : photo, prénom, chiffres clés, statut, actions.
/// Le toucher ouvre son profil.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    this.leading,
    this.stats = const [],
    this.status,
    this.subtitle,
    this.actions = const [],
    this.onTap,
  });

  final String name;

  /// Photo ou pastille d'arrêt ; par défaut l'initiale.
  final Widget? leading;
  final List<UmStat> stats;
  final Widget? status;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: UmSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              leading ?? UmAvatar(name: name),
              const SizedBox(width: UmSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: UmText.bodySm.copyWith(color: c.inkMuted),
                      ),
                    if (stats.isNotEmpty)
                      Wrap(spacing: UmSpace.s3, runSpacing: UmSpace.s1, children: stats),
                  ],
                ),
              ),
              if (status != null) ...[const SizedBox(width: UmSpace.s2), status!],
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: UmSpace.s2),
            Padding(
              padding: const EdgeInsets.only(left: UmSize.avatar + UmSpace.s3),
              child: Wrap(spacing: UmSpace.s2, runSpacing: UmSpace.s2, children: actions),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(borderRadius: BorderRadius.circular(UmRadius.sm), onTap: onTap, child: body);
  }
}

/// Note sur 5 et détour : les deux chiffres qui comptent avant d'accepter quelqu'un.
List<UmStat> personStats(AppLocalizations l10n, PublicPerson person, {required bool isDriver}) => [
  UmStat(
    icon: Icons.star_rounded,
    value: person.scoreOutOfFive,
    semantic: l10n.statScore(person.scoreOutOfFive),
  ),
  UmStat(
    icon: Icons.timer_outlined,
    value: l10n.statDetour(person.detourMinutes),
    semantic: isDriver
        ? l10n.statDetourDriver(person.detourMinutes)
        : l10n.statDetourPassenger(person.detourMinutes),
  ),
];

/// Statut d'une personne sur un trajet : a accepté, attend, demande une place.
Widget? personStatusChip(AppLocalizations l10n, String status) => switch (status) {
  'accepted' => UmChip(
    label: l10n.personAccepted,
    icon: Icons.check_circle_rounded,
    tone: UmChipTone.success,
  ),
  'requested' => UmChip(label: l10n.personRequested, icon: Icons.front_hand_outlined),
  'proposed' => UmChip(label: l10n.personPending, icon: Icons.hourglass_empty_rounded),
  _ => null,
};

/// Les personnes qui ont refusé ou annulé disparaissent de la liste et de la carte.
bool personVisible(PublicPerson p) => p.status != 'declined' && p.status != 'cancelled';

/// Prix en quelques puces : montant en grand, puis le détail en une ligne par élément.
class PriceBullets extends StatelessWidget {
  const PriceBullets({super.key, required this.price, required this.isDriver, this.distanceM});

  final RidePrice? price;
  final bool isDriver;

  /// Longueur du trajet entier (pour « ta part : 7,5 km sur 12 km »).
  final int? distanceM;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final p = price;
    if (p == null) {
      return Text(l10n.ridePriceUnknown, style: UmText.bodySm.copyWith(color: c.inkMuted));
    }
    String euros(int cents) => UmRideCard.formatPrice(cents, l10n.localeName);
    String km(int meters) => NumberFormat('0.#', l10n.localeName).format(meters / 1000);
    final amount = euros((isDriver ? p.youReceiveCents : p.youPayCents) ?? 0);
    final bullets = [
      l10n.priceBulletFuel(euros(p.totalCostCents)),
      if (!isDriver && p.myDistanceM != null && distanceM != null)
        l10n.priceBulletShare(km(p.myDistanceM!), km(distanceM!))
      else
        l10n.priceBulletPersons(p.persons),
      if (!isDriver) l10n.priceBulletCommission(euros(p.commissionCents)),
      l10n.priceBulletFinal,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: isDriver ? l10n.ridePriceYouReceive(amount) : l10n.ridePriceYouPay(amount),
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isDriver ? l10n.ridePriceReceiveLabel : l10n.ridePricePayLabel,
                style: UmText.label.copyWith(color: c.inkMuted),
              ),
              const SizedBox(width: UmSpace.s2),
              Text(amount, style: UmText.h2.copyWith(color: c.brandStrong)),
            ],
          ),
        ),
        const SizedBox(height: UmSpace.s1),
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(top: UmSpace.s1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: UmText.bodySm.copyWith(color: c.inkMuted)),
                Expanded(
                  child: Text(b, style: UmText.bodySm.copyWith(color: c.inkMuted)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
