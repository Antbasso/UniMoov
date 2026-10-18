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

/// Prix du trajet : le montant seul, et le calcul précis replié dessous (« Détail du
/// calcul ») : kilomètres × consommation × prix du litre, puis les portions partagées.
class PriceBullets extends StatelessWidget {
  const PriceBullets({super.key, required this.price, required this.isDriver, this.distanceM});

  final RidePrice? price;
  final bool isDriver;
  final int? distanceM;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final p = price;
    if (p == null) {
      return Text(l10n.ridePriceUnknown, style: UmText.bodySm.copyWith(color: c.inkMuted));
    }
    String euros(num cents) => UmRideCard.formatPrice(cents.round(), l10n.localeName);
    final amount = euros((isDriver ? p.youReceiveCents : p.youPayCents) ?? 0);
    final b = p.breakdown;
    final passengers = b?.shares.length ?? 0;
    final header = Semantics(
      label: isDriver
          ? l10n.ridePriceYouReceiveTotal(amount, passengers)
          : l10n.ridePriceYouPay(amount),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Texte agrandi : le montant passe sous le libellé plutôt que de déborder.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: UmSpace.s2,
            children: [
              Text(
                isDriver ? l10n.ridePriceReceiveTotalLabel : l10n.ridePricePayLabel,
                style: UmText.label.copyWith(color: c.inkMuted),
              ),
              Text(amount, style: UmText.h2.copyWith(color: c.brandStrong)),
            ],
          ),
          if (isDriver && passengers > 0)
            Text(
              l10n.ridePriceFromPassengers(passengers),
              style: UmText.bodySm.copyWith(color: c.inkMuted),
            ),
        ],
      ),
    );
    if (b == null) return header;

    final number = NumberFormat('0.##', l10n.localeName);
    String km(int meters) => number.format(meters / 1000);
    final perMeter = b.distanceM == 0 ? 0.0 : p.totalCostCents / b.distanceM;
    final sharesSum = b.shares.fold<int>(0, (sum, s) => sum + s.shareCents);

    // Trois étapes, chacune avec son résultat : le carburant du trajet, le partage tronçon par
    // tronçon, puis l'addition qui donne exactement le montant affiché en haut.
    final steps = <Widget>[
      _CalcStep(
        number: 1,
        title: l10n.calcStepFuel,
        lines: [
          (
            l10n.calcLitres(
              km(b.distanceM),
              number.format(b.consumptionLPer100km),
              number.format(b.litres),
            ),
            null,
          ),
          (l10n.calcFuel(number.format(b.litres), euros(b.fuelPriceCentsPerLitre)), null),
        ],
        result: (l10n.calcTripCost, euros(p.totalCostCents)),
      ),
      if (b.portions.isNotEmpty)
        _CalcStep(
          number: 2,
          title: l10n.calcStepShare,
          note: l10n.calcStepShareNote,
          lines: [
            for (final portion in b.portions)
              (
                l10n.calcPortionEach(
                  km(portion.distanceM),
                  euros(portion.distanceM * perMeter),
                  portion.persons,
                ),
                euros(portion.distanceM * perMeter / portion.persons),
              ),
          ],
          result: isDriver ? null : (l10n.calcMyShare, euros(p.shareCents)),
        ),
      if (isDriver)
        _CalcStep(
          number: b.portions.isEmpty ? 2 : 3,
          title: l10n.calcStepReceive,
          lines: [
            for (final share in b.shares)
              (l10n.calcShareOf(share.firstName), euros(share.shareCents)),
          ],
          result: (l10n.calcTotalReceived, euros(sharesSum)),
          // Vérification : ce que tu reçois + ta propre part = le coût du trajet.
          footnote: l10n.calcDriverCheck(
            euros(sharesSum),
            euros(p.totalCostCents - sharesSum),
            euros(p.totalCostCents),
          ),
        )
      else
        _CalcStep(
          number: b.portions.isEmpty ? 2 : 3,
          title: l10n.calcStepPay,
          lines: [
            (l10n.calcMyShare, euros(p.shareCents)),
            (l10n.calcCommissionPlus, euros(p.commissionCents)),
          ],
          result: (l10n.calcTotalPaid, euros(p.shareCents + p.commissionCents)),
        ),
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: UmSpace.s2),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: header,
        subtitle: Text(l10n.calcTitle, style: UmText.caption.copyWith(color: c.brandStrong)),
        children: [
          for (final step in steps) ...[step, const SizedBox(height: UmSpace.s3)],
          Text(l10n.calcRounding, style: UmText.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: UmSpace.s1),
          Text(l10n.priceBulletFinal, style: UmText.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}

/// Une étape du calcul : numéro et titre, lignes « libellé … montant », puis son résultat
/// souligné d'un filet, comme une addition posée.
class _CalcStep extends StatelessWidget {
  const _CalcStep({
    required this.number,
    required this.title,
    required this.lines,
    this.result,
    this.note,
    this.footnote,
  });

  final int number;
  final String title;
  final List<(String, String?)> lines;
  final (String, String)? result;
  final String? note;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    Widget row(String label, String? value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(top: UmSpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: UmText.bodySm.copyWith(
                color: strong ? c.ink : c.inkMuted,
                fontWeight: strong ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: UmSpace.s3),
            Text(
              value,
              style: UmText.bodySm.copyWith(
                color: c.ink,
                fontWeight: strong ? FontWeight.w600 : null,
              ),
            ),
          ],
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(UmSpace.s3),
      decoration: BoxDecoration(
        color: c.surfaceTint,
        borderRadius: BorderRadius.circular(UmRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('$number. $title', style: UmText.label.copyWith(color: c.brandStrong)),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: UmSpace.s1),
              child: Text(note!, style: UmText.caption.copyWith(color: c.inkMuted)),
            ),
          for (final (label, value) in lines) row(label, value),
          if (result case (final label, final value)) ...[
            const SizedBox(height: UmSpace.s2),
            Divider(height: 1, color: c.borderControl),
            row(label, value, strong: true),
          ],
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: UmSpace.s2),
              child: Text(footnote!, style: UmText.caption.copyWith(color: c.inkMuted)),
            ),
        ],
      ),
    );
  }
}
