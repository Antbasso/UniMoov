import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../rides/presentation/trip_widgets.dart';
import '../domain/me.dart';
import 'me_controller.dart';
import 'person_avatar.dart';

/// Profil d'une personne croisée sur un trajet ou une conversation : photo, prénom, âge,
/// formation, centres d'intérêt, note et trajets menés. Jamais de nom de famille ni d'adresse.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final profile = ref.watch(publicProfileProvider(userId));
    return UmPage(
      appBar: AppBar(),
      children: switch (profile) {
        AsyncData(:final value) => _content(context, l10n, value),
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

  List<Widget> _content(BuildContext context, AppLocalizations l10n, PublicProfile p) {
    final c = context.umColors;
    return [
      Center(
        child: PersonAvatar(name: p.firstName, photoUrl: p.photoUrl, size: UmSize.avatarXl),
      ),
      const SizedBox(height: UmSpace.s3),
      Semantics(
        header: true,
        child: Text(
          p.age == null ? p.firstName : l10n.profileNameAge(p.firstName, p.age!),
          textAlign: TextAlign.center,
          style: UmText.h1.copyWith(color: c.ink),
        ),
      ),
      if (p.studyProgram != null) ...[
        const SizedBox(height: UmSpace.s1),
        Text(
          p.studyProgram!,
          textAlign: TextAlign.center,
          style: UmText.body.copyWith(color: c.inkMuted),
        ),
      ],
      const SizedBox(height: UmSpace.s4),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: UmSpace.s5,
        runSpacing: UmSpace.s2,
        children: [
          UmStat(
            icon: Icons.star_rounded,
            value: p.scoreOutOfFive,
            semantic: l10n.statScore(p.scoreOutOfFive),
          ),
          UmStat(
            icon: Icons.directions_car_outlined,
            value: '${p.ridesCompleted}',
            semantic: l10n.statRides(p.ridesCompleted),
          ),
        ],
      ),
      if (p.interests.isNotEmpty) ...[
        const SizedBox(height: UmSpace.s5),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: UmSpace.s2,
          runSpacing: UmSpace.s2,
          children: [for (final i in p.interests) UmChip(label: i)],
        ),
      ],
    ];
  }
}
