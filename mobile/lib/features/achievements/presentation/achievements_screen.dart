import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/achievements.dart';
import 'achievement_labels.dart';
import 'achievements_controller.dart';
import 'badge_medal.dart';
import 'leaderboard_screen.dart';

/// « Mes réussites » : niveau et points, impact (CO₂, km, économies), badges, classement du
/// campus du mois, avec le choix d'y apparaître sous son prénom.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final state = ref.watch(achievementsProvider);
    return UmPage(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      children: switch (state) {
        AsyncData(:final value) => [
          LevelCard(achievements: value),
          const SizedBox(height: UmSpace.s5),
          _Impact(a: value),
          const SizedBox(height: UmSpace.s6),
          UmSectionTitle(l10n.badgesTitle(value.earnedCount, value.badges.length)),
          const SizedBox(height: UmSpace.s3),
          for (final badge in value.badges) _BadgeRow(badge: badge),
          const SizedBox(height: UmSpace.s6),
          LeaderboardCard(achievements: value),
        ],
        AsyncError(:final error) => [
          UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
          const SizedBox(height: UmSpace.s2),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(achievementsProvider),
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

/// Niveau, points et avancée vers le niveau suivant (aussi en tête du profil).
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.achievements, this.onTap});

  final Achievements achievements;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final a = achievements;
    final next = a.nextKey;
    final remaining = (a.nextMin ?? a.points) - a.points;
    final caption = next == null ? l10n.levelTop : l10n.levelNext(remaining, levelName(l10n, next));
    final card = Container(
      padding: const EdgeInsets.all(UmSpace.s4),
      decoration: BoxDecoration(
        color: c.lavender,
        borderRadius: BorderRadius.circular(UmRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: UmSize.avatarLg,
            height: UmSize.avatarLg,
            decoration: BoxDecoration(color: c.brandStrong, shape: BoxShape.circle),
            child: Icon(levelIcon(a.levelKey), color: c.onBrand, size: UmSize.iconMd),
          ),
          const SizedBox(width: UmSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(levelName(l10n, a.levelKey), style: UmText.h3.copyWith(color: c.brandStrong)),
                Text(l10n.pointsCount(a.points), style: UmText.bodySm.copyWith(color: c.ink)),
                const SizedBox(height: UmSpace.s2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(UmRadius.pill),
                  child: LinearProgressIndicator(
                    value: a.progress,
                    minHeight: UmSpace.s2,
                    color: c.brandStrong,
                    backgroundColor: c.surfaceRaised,
                  ),
                ),
                const SizedBox(height: UmSpace.s1),
                Text(caption, style: UmText.caption.copyWith(color: c.ink)),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.brandStrong),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '${levelName(l10n, a.levelKey)}, ${l10n.pointsCount(a.points)}. $caption',
      excludeSemantics: true,
      child: onTap == null
          ? card
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(UmRadius.md),
                onTap: onTap,
                child: card,
              ),
            ),
    );
  }
}

class _Impact extends StatelessWidget {
  const _Impact({required this.a});

  final Achievements a;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = UmRideCard.formatPrice(
      a.receivedCents > 0 ? a.receivedCents : a.paidCents,
      l10n.localeName,
    );
    final tiles = [
      (Icons.eco_outlined, '${a.co2SavedKg} kg', l10n.impactCo2),
      (Icons.route_outlined, '${a.sharedKm} km', l10n.impactKm),
      (Icons.directions_car_outlined, '${a.rides}', l10n.impactRides),
      (Icons.euro_rounded, money, a.receivedCents > 0 ? l10n.impactReceived : l10n.impactPaid),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Deux par ligne, une seule colonne si le texte est très agrandi.
        final width = constraints.maxWidth < 280
            ? constraints.maxWidth
            : (constraints.maxWidth - UmSpace.s3) / 2;
        return Wrap(
          spacing: UmSpace.s3,
          runSpacing: UmSpace.s3,
          children: [
            for (final (icon, value, label) in tiles)
              SizedBox(
                width: width,
                child: _ImpactTile(icon: icon, value: value, label: label),
              ),
          ],
        );
      },
    );
  }
}

class _ImpactTile extends StatelessWidget {
  const _ImpactTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      label: '$value, $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(UmSpace.s3),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(UmRadius.md),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c.success),
            const SizedBox(height: UmSpace.s1),
            Text(value, style: UmText.h3.copyWith(color: c.ink)),
            Text(label, style: UmText.caption.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final status = badge.earned ? l10n.badgeEarned : l10n.badgeProgress(badge.progress, badge.goal);
    // Toucher un badge : la médaille en grand, en 3D.
    return Semantics(
      button: true,
      label: '${badgeName(l10n, badge.key)}. ${badgeGoal(l10n, badge.key)} $status',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(UmRadius.sm),
        onTap: () => showBadgeViewer(context, badge),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: UmSpace.s2),
          child: Row(
            children: [
              BadgeMedal(badgeKey: badge.key, earned: badge.earned, size: UmSize.avatarLg),
              const SizedBox(width: UmSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badgeName(l10n, badge.key),
                      style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      badgeGoal(l10n, badge.key),
                      style: UmText.bodySm.copyWith(color: c.inkMuted),
                    ),
                    if (!badge.earned) ...[
                      const SizedBox(height: UmSpace.s1),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(UmRadius.pill),
                        child: LinearProgressIndicator(
                          value: badge.goal == 0 ? 0 : badge.progress / badge.goal,
                          minHeight: UmSpace.s1,
                          color: c.brand,
                          backgroundColor: c.lavender,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: UmSpace.s2),
              // Statut en texte (pas seulement la couleur de la pastille).
              badge.earned
                  ? UmChip(label: status, icon: Icons.check_rounded, tone: UmChipTone.success)
                  : Text(status, style: UmText.caption.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
