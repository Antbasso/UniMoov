import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/me_controller.dart';
import '../../profile/presentation/person_avatar.dart';
import '../domain/achievements.dart';
import 'achievement_labels.dart';
import 'achievements_controller.dart';

/// Carte du classement, mise en avant sur l'accueil et dans « Mes réussites » : ma place du
/// mois, le toucher ouvre le classement complet.
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key, required this.achievements});

  final Achievements achievements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final rank = achievements.monthRank;
    final text = rank == null
        ? l10n.homeLeaderboardNone
        : l10n.homeLeaderboardRank(rank, achievements.ranked);
    return Semantics(
      button: true,
      label: '${l10n.homeLeaderboardTitle}. $text',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(UmRadius.md),
          onTap: () => context.push(AppRoutes.leaderboard),
          child: Container(
            padding: const EdgeInsets.all(UmSpace.s4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UmRadius.md),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: UmSize.avatar / 2,
                  backgroundColor: c.lavender,
                  child: Icon(Icons.leaderboard_rounded, color: c.brandStrong),
                ),
                const SizedBox(width: UmSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.homeLeaderboardTitle, style: UmText.h3.copyWith(color: c.ink)),
                      Text(text, style: UmText.bodySm.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                if (rank != null) Text('$rank', style: UmText.h2.copyWith(color: c.brandStrong)),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Classement du campus du mois : podium des trois premiers, puis la liste ; choix d'y
/// apparaître sous son prénom (sinon anonyme).
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final board = ref.watch(leaderboardProvider);
    final visible = ref.watch(meProvider.select((m) => m.value?.leaderboardVisible ?? false));
    return UmPage(
      appBar: AppBar(
        title: Text(
          board.value == null
              ? l10n.leaderboardTitle
              : l10n.leaderboardTitleMonth(
                  DateFormat('MMMM', l10n.localeName).format(board.value!.month),
                ),
        ),
      ),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: visible,
          title: Text(l10n.leaderboardShowMe),
          subtitle: Text(l10n.leaderboardShowMeHelp),
          onChanged: (value) async {
            await ref.read(meProvider.notifier).setLeaderboardVisible(value);
            ref
              ..invalidate(achievementsProvider)
              ..invalidate(leaderboardProvider);
          },
        ),
        const SizedBox(height: UmSpace.s4),
        ...switch (board) {
          AsyncData(:final value) when value.entries.isEmpty => [
            Text(l10n.leaderboardEmpty, style: UmText.body.copyWith(color: c.inkMuted)),
          ],
          AsyncData(:final value) => [
            UmSectionTitle(l10n.leaderboardPodium),
            const SizedBox(height: UmSpace.s3),
            _Podium(entries: value.entries.take(3).toList()),
            const SizedBox(height: UmSpace.s5),
            for (final e in value.entries.skip(3)) _LeaderRow(entry: e),
            if (value.myRank != null && !value.entries.any((e) => e.me))
              Padding(
                padding: const EdgeInsets.only(top: UmSpace.s2),
                child: Text(
                  l10n.leaderboardMyRank(value.myRank!, value.ranked),
                  style: UmText.body.copyWith(color: c.brandStrong),
                ),
              ),
          ],
          AsyncError(:final error) => [
            UmErrorText(apiErrorMessage(l10n, error is ApiException ? error.code : null)),
            UmButton(
              label: l10n.retry,
              variant: UmButtonVariant.ghost,
              onPressed: () => ref.invalidate(leaderboardProvider),
            ),
          ],
          _ => [Semantics(label: l10n.loading, child: const LinearProgressIndicator())],
        },
      ],
    );
  }
}

/// Les trois premières places en marches de podium (2e, 1re, 3e), photo et points dessus.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final order = [
      if (entries.length > 1) (entries[1], UmSpace.s8),
      if (entries.isNotEmpty) (entries[0], UmSpace.s8 + UmSpace.s6),
      if (entries.length > 2) (entries[2], UmSpace.s7),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (e, height) in order)
          Expanded(
            child: Semantics(
              label: l10n.leaderboardRowSemantic(e.rank, _name(l10n, e), e.points),
              excludeSemantics: true,
              child: Column(
                children: [
                  PersonAvatar(
                    name: e.firstName ?? '?',
                    photoUrl: e.photoUrl,
                    size: e.rank == 1 ? UmSize.avatarLg : UmSize.avatar,
                  ),
                  const SizedBox(height: UmSpace.s1),
                  Text(
                    _name(l10n, e),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UmText.label.copyWith(color: c.ink),
                  ),
                  Text(
                    l10n.pointsShort(e.points),
                    style: UmText.caption.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: UmSpace.s1),
                  Container(
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: UmSpace.s1),
                    decoration: BoxDecoration(
                      color: e.me ? c.brand : (e.rank == 1 ? c.brandStrong : c.lavender),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(UmRadius.sm)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${e.rank}',
                      style: UmText.h2.copyWith(
                        color: e.me || e.rank == 1 ? c.onBrand : c.brandStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _name(AppLocalizations l10n, LeaderEntry e) =>
    e.me ? l10n.leaderboardYou : (e.firstName ?? l10n.leaderboardAnonymous);

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry});

  final LeaderEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final name = _name(l10n, entry);
    return Semantics(
      label: l10n.leaderboardRowSemantic(entry.rank, name, entry.points),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: UmSpace.s2),
        padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3, vertical: UmSpace.s2),
        decoration: BoxDecoration(
          color: entry.me ? c.lavender : c.surfaceRaised,
          borderRadius: BorderRadius.circular(UmRadius.sm),
          border: Border.all(color: entry.me ? c.brandStrong : c.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: UmSpace.s6,
              child: Text('${entry.rank}', style: UmText.h3.copyWith(color: c.brandStrong)),
            ),
            PersonAvatar(name: entry.firstName ?? '?', photoUrl: entry.photoUrl),
            const SizedBox(width: UmSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: UmText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    levelName(l10n, entry.levelKey),
                    style: UmText.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Text(l10n.pointsShort(entry.points), style: UmText.body.copyWith(color: c.ink)),
          ],
        ),
      ),
    );
  }
}
