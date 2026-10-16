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

  /// Étoiles choisies, pas encore envoyées : un appui raté se corrige avant d'envoyer.
  final Map<String, int> _draft = {};

  Future<void> _rate(RatingTarget person, int stars) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = AppLocalizations.of(context).ratingDone;
    setState(() {
      _busyFor = person.userId;
      _errorCode = null;
    });
    try {
      await ref.read(ratingsProvider(widget.rideId).notifier).rate(person.userId, stars);
      _draft.remove(person.userId);
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
    final value = ratings.value;
    if (value == null) {
      if (ratings.isLoading) {
        return Semantics(
          label: l10n.loading,
          child: LinearProgressIndicator(color: c.brand),
        );
      }
      final error = ratings.error;
      // Pas de droit de noter (absent, tiers) : rien à afficher. Autre erreur : message et réessai.
      if (error is ApiException && error.statusCode == 403) return const SizedBox.shrink();
      return UmCard(
        title: l10n.ratingTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
            UmButton(
              label: l10n.retry,
              variant: UmButtonVariant.ghost,
              onPressed: () => ref.invalidate(ratingsProvider(widget.rideId)),
            ),
          ],
        ),
      );
    }
    if (value.people.isEmpty) return const SizedBox.shrink();
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
            else if (value.open) ...[
              Row(
                children: [
                  for (var n = 1; n <= 5; n++)
                    IconButton(
                      tooltip: l10n.ratingStar(n, person.firstName),
                      isSelected: (_draft[person.userId] ?? 0) >= n,
                      constraints: const BoxConstraints(
                        minWidth: UmSize.tapTarget,
                        minHeight: UmSize.tapTarget,
                      ),
                      icon: Icon(Icons.star_outline_rounded, color: c.brandStrong),
                      selectedIcon: Icon(Icons.star_rounded, color: c.brandStrong),
                      onPressed: _busyFor == null
                          ? () => setState(() => _draft[person.userId] = n)
                          : null,
                    ),
                ],
              ),
              if (_draft[person.userId] case final stars?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: UmButton(
                    label: l10n.ratingSend(stars),
                    variant: UmButtonVariant.secondary,
                    loading: _busyFor == person.userId,
                    onPressed: _busyFor == null ? () => _rate(person, stars) : null,
                  ),
                ),
            ],
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
