import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/trust.dart';
import 'trust_controller.dart';

/// Notation croisée facultative après un trajet terminé (cahier §7) : une note de 1 à 5
/// par personne, une seule fois.
class RatingCard extends ConsumerStatefulWidget {
  const RatingCard({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends ConsumerState<RatingCard> {
  String? _busyFor;
  String? _errorCode;

  Future<void> _rate(RatingTarget person, int stars) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = AppLocalizations.of(context).ratingDone;
    setState(() {
      _busyFor = person.userId;
      _errorCode = null;
    });
    try {
      await ref.read(ratingsProvider(widget.rideId).notifier).rate(person.userId, stars);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _busyFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final ratings = ref.watch(ratingsProvider(widget.rideId));
    // Personne à noter (passager absent, tiers) ou erreur de lecture : la carte ne s'affiche pas.
    final value = ratings.value;
    if (value == null || value.people.isEmpty) {
      return ratings.isLoading
          ? Semantics(
              label: l10n.loading,
              child: LinearProgressIndicator(color: c.brand),
            )
          : const SizedBox.shrink();
    }
    return UmCard(
      title: l10n.ratingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value.open ? l10n.ratingIntro : l10n.ratingClosed,
            style: UmText.bodySm.copyWith(color: c.inkMuted),
          ),
          for (final person in value.people) ...[
            const SizedBox(height: UmSpace.s3),
            Text(
              person.firstName,
              style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
            ),
            Text(
              person.isDriver ? l10n.ratingDriver : l10n.ratingPassenger,
              style: UmText.caption.copyWith(color: c.inkMuted),
            ),
            if (person.stars case final stars?)
              _Stars(value: stars, label: l10n.ratingGiven(stars))
            else if (value.open)
              Row(
                children: [
                  for (var n = 1; n <= 5; n++)
                    IconButton(
                      tooltip: l10n.ratingStar(n, person.firstName),
                      constraints: const BoxConstraints(
                        minWidth: UmSize.tapTarget,
                        minHeight: UmSize.tapTarget,
                      ),
                      icon: Icon(Icons.star_outline_rounded, color: c.brandStrong),
                      onPressed: _busyFor == null ? () => _rate(person, n) : null,
                    ),
                ],
              ),
          ],
          if (_errorCode != null) ...[
            const SizedBox(height: UmSpace.s3),
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
          ],
        ],
      ),
    );
  }
}

/// Note donnée : étoiles pleines plus le texte (le sens ne passe pas que par l'icône).
class _Stars extends StatelessWidget {
  const _Stars({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: UmSpace.s1),
        child: Row(
          children: [
            for (var n = 1; n <= 5; n++)
              Icon(
                n <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: UmSize.iconMd,
                color: c.brandStrong,
              ),
            const SizedBox(width: UmSpace.s2),
            Text(label, style: UmText.bodySm.copyWith(color: c.ink)),
          ],
        ),
      ),
    );
  }
}
