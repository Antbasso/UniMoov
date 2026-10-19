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
import '../../achievements/presentation/achievement_labels.dart';
import '../../chat/data/chat_api.dart';
import '../domain/me.dart';
import 'me_controller.dart';
import 'person_avatar.dart';
import 'profile_labels.dart';

/// Profil d'une personne croisée sur un trajet ou une conversation, façon covoiturage : photo
/// et niveau, note, « Écrire », profil vérifié, à propos (formation, âge, mini-bio),
/// préférences, centres d'intérêt, badges, puis ses chiffres. Jamais de nom de famille ni
/// d'adresse.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final profile = ref.watch(publicProfileProvider(userId));
    final mine = ref.watch(meProvider.select((m) => m.value?.id)) == userId;
    return UmPage(
      appBar: AppBar(),
      children: switch (profile) {
        AsyncData(:final value) => [_Profile(p: value, mine: mine)],
        AsyncError(:final error) => [
          UmErrorText(
            error is ApiException && error.code == 'not_found'
                ? l10n.profileUnavailable
                : apiErrorMessage(l10n, error is ApiException ? error.code : null),
          ),
          const SizedBox(height: UmSpace.s2),
          UmButton(
            label: l10n.retry,
            variant: UmButtonVariant.ghost,
            onPressed: () => ref.invalidate(publicProfileProvider(userId)),
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

class _Profile extends ConsumerStatefulWidget {
  const _Profile({required this.p, required this.mine});

  final PublicProfile p;
  final bool mine;

  @override
  ConsumerState<_Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<_Profile> {
  bool _opening = false;
  String? _errorCode;

  /// « Écrire » : la conversation privée avec cette personne (créée si besoin).
  Future<void> _write() async {
    final router = GoRouter.of(context);
    setState(() {
      _opening = true;
      _errorCode = null;
    });
    try {
      final conversation = await ref.read(chatApiProvider).createDirect(widget.p.id);
      await router.push(AppRoutes.conversation(conversation.id));
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorCode = error.code);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final p = widget.p;
    final name = p.firstName;
    final since = p.memberSince == null
        ? null
        : DateFormat('MMMM yyyy', l10n.localeName).format(p.memberSince!);
    final prefs = [
      if (p.preferences.chat case final v?) ('chat', v),
      if (p.preferences.music case final v?) ('music', v),
      if (p.preferences.smoking case final v?) ('smoking', v),
      if (p.preferences.pets case final v?) ('pets', v),
    ];
    final about = [
      if (p.studyProgram case final s?) (Icons.school_outlined, s),
      if (p.age case final a?) (Icons.cake_outlined, l10n.ageYears(a)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête : photo cerclée de la couleur du niveau, prénom, note, niveau.
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(UmSpace.s1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.brandStrong, width: UmSize.routeRing),
                  ),
                  child: PersonAvatar(name: name, photoUrl: p.photoUrl, size: UmSize.avatarXl),
                ),
                Positioned(
                  right: -UmSpace.s1,
                  bottom: -UmSpace.s1,
                  child: CircleAvatar(
                    radius: UmSize.iconMd / 2 + UmSpace.s1,
                    backgroundColor: c.brandStrong,
                    child: Icon(levelIcon(p.levelKey), size: UmSize.iconSm, color: c.onBrand),
                  ),
                ),
              ],
            ),
            const SizedBox(width: UmSpace.s5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      p.age == null ? name : l10n.profileNameAge(name, p.age!),
                      style: UmText.h2.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(height: UmSpace.s1),
                  _IconLine(
                    icon: Icons.star_rounded,
                    text: l10n.profileRating(p.scoreOutOfFive, p.ratingsCount),
                  ),
                  _IconLine(icon: levelIcon(p.levelKey), text: levelName(l10n, p.levelKey)),
                ],
              ),
            ),
          ],
        ),
        if (!widget.mine) ...[
          const SizedBox(height: UmSpace.s5),
          UmButton(
            label: l10n.profileWrite(name),
            icon: Icons.chat_bubble_outline_rounded,
            variant: UmButtonVariant.secondary,
            expand: true,
            loading: _opening,
            onPressed: _write,
          ),
          if (_errorCode != null) ...[
            const SizedBox(height: UmSpace.s2),
            UmErrorText(apiErrorMessage(l10n, _errorCode)),
          ],
        ] else ...[
          const SizedBox(height: UmSpace.s5),
          UmButton(
            label: l10n.profileEditMine,
            icon: Icons.edit_outlined,
            variant: UmButtonVariant.secondary,
            expand: true,
            onPressed: () => context.push(AppRoutes.profileAbout),
          ),
        ],
        const _Separator(),
        UmSectionTitle(l10n.profileVerifiedTitle(name)),
        const SizedBox(height: UmSpace.s3),
        _Check(text: l10n.profileVerifiedEmail),
        if (since != null) _Check(text: l10n.profileMemberSince(since)),
        const _Separator(),
        UmSectionTitle(l10n.profileAboutTitle(name)),
        if (about.isEmpty && p.bio == null)
          Padding(
            padding: const EdgeInsets.only(top: UmSpace.s3),
            child: Text(
              l10n.profileAboutEmpty(name),
              style: UmText.body.copyWith(color: c.inkMuted),
            ),
          ),
        for (final (icon, text) in about)
          Padding(
            padding: const EdgeInsets.only(top: UmSpace.s3),
            child: _IconLine(icon: icon, text: text, large: true),
          ),
        if (p.bio case final bio?) ...[
          const SizedBox(height: UmSpace.s4),
          Text(l10n.aboutBio, style: UmText.label.copyWith(color: c.ink)),
          const SizedBox(height: UmSpace.s1),
          Text(bio, style: UmText.body.copyWith(color: c.inkMuted)),
        ],
        if (prefs.isNotEmpty) ...[
          const SizedBox(height: UmSpace.s5),
          Text(l10n.prefsTitle, style: UmText.label.copyWith(color: c.ink)),
          for (final (kind, value) in prefs)
            Padding(
              padding: const EdgeInsets.only(top: UmSpace.s3),
              child: _IconLine(
                icon: preferenceIcon(kind, value),
                text: preferenceLabel(l10n, kind, value),
                large: true,
              ),
            ),
        ],
        if (p.interests.isNotEmpty) ...[
          const SizedBox(height: UmSpace.s5),
          Text(l10n.aboutInterests, style: UmText.label.copyWith(color: c.ink)),
          const SizedBox(height: UmSpace.s2),
          Wrap(
            spacing: UmSpace.s2,
            runSpacing: UmSpace.s2,
            children: [for (final i in p.interests) InterestChip(label: i)],
          ),
        ],
        if (p.badges.isNotEmpty) ...[
          const _Separator(),
          UmSectionTitle(l10n.profileBadges),
          const SizedBox(height: UmSpace.s3),
          Wrap(
            spacing: UmSpace.s2,
            runSpacing: UmSpace.s2,
            children: [
              for (final b in p.badges) UmChip(label: badgeName(l10n, b), icon: badgeIcon(b)),
            ],
          ),
        ],
        const _Separator(),
        // Ses chiffres, en lignes simples comme sur les applis de covoiturage.
        for (final line in [
          l10n.profileRides(p.ridesCompleted),
          l10n.profileCancellationRate(p.cancellationRate),
          if (p.co2SavedKg > 0) l10n.profileCo2(p.co2SavedKg),
        ]) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: UmSpace.s3),
            child: Text(line, style: UmText.body.copyWith(color: c.inkMuted)),
          ),
          Divider(height: 1, color: c.border),
        ],
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.large = false});

  final IconData icon;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: large ? UmSize.iconMd : UmSize.iconSm, color: c.inkMuted),
        SizedBox(width: large ? UmSpace.s3 : UmSpace.s2),
        Expanded(
          child: Text(text, style: (large ? UmText.body : UmText.bodySm).copyWith(color: c.ink)),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: UmSpace.s3),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: c.success),
          const SizedBox(width: UmSpace.s3),
          Expanded(
            child: Text(text, style: UmText.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}

/// Bande de séparation entre les blocs du profil.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: UmSpace.s5),
    child: Divider(height: 1, thickness: UmSpace.s2, color: context.umColors.surfaceTint),
  );
}
