import 'package:flutter/material.dart';

import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Charte de bonne conduite (docs/charte-bonne-conduite.md) : acceptée à l'inscription,
/// relisible depuis le profil. Lisible sans être connecté.
class CharterScreen extends StatelessWidget {
  const CharterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final sections = [
      (Icons.favorite_border_rounded, l10n.charter1Title, l10n.charter1Body),
      (Icons.schedule_rounded, l10n.charter2Title, l10n.charter2Body),
      (Icons.verified_outlined, l10n.charter3Title, l10n.charter3Body),
      (Icons.health_and_safety_outlined, l10n.charter4Title, l10n.charter4Body),
      (Icons.euro_rounded, l10n.charter5Title, l10n.charter5Body),
      (Icons.event_seat_outlined, l10n.charter6Title, l10n.charter6Body),
      (Icons.lock_outline_rounded, l10n.charter7Title, l10n.charter7Body),
      (Icons.flag_outlined, l10n.charter8Title, l10n.charter8Body),
      (Icons.gavel_rounded, l10n.charter9Title, l10n.charter9Body),
    ];
    return UmPage(
      appBar: AppBar(),
      title: l10n.charterTitle,
      intro: l10n.charterIntro,
      children: [
        for (final (i, (icon, title, body)) in sections.indexed) ...[
          Row(
            children: [
              Icon(icon, color: c.brandStrong),
              const SizedBox(width: UmSpace.s3),
              Expanded(child: UmSectionTitle('${i + 1}. $title')),
            ],
          ),
          const SizedBox(height: UmSpace.s2),
          for (final line in body.split('\n'))
            Padding(
              padding: const EdgeInsets.only(left: UmSpace.s6 + UmSpace.s1, bottom: UmSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Text('•', style: UmText.body.copyWith(color: c.brandStrong)),
                  ),
                  const SizedBox(width: UmSpace.s2),
                  Expanded(
                    child: Text(line, style: UmText.body.copyWith(color: c.ink)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: UmSpace.s4),
        ],
      ],
    );
  }
}
