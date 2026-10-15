import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

enum UmChipTone { neutral, success, danger }

/// Puce d'information courte (docs/design-system/components/Chip.md). Un statut porte
/// toujours un mot et une icône : jamais la couleur seule.
class UmChip extends StatelessWidget {
  const UmChip({super.key, required this.label, this.icon, this.tone = UmChipTone.neutral})
    : assert(tone == UmChipTone.neutral || icon != null, 'Un statut exige une icône');

  final String label;
  final IconData? icon;
  final UmChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final (background, foreground) = switch (tone) {
      UmChipTone.neutral => (c.lavender, c.brandStrong),
      UmChipTone.success => (c.successSoft, c.success),
      UmChipTone.danger => (c.dangerSoft, c.danger),
    };
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UmSpace.s3, vertical: UmSpace.s1),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(UmRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: UmSpace.s1),
            ],
            Flexible(
              child: Text(label, style: UmText.label.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticker manuscrit (Caveat, `brand-strong` sur `lavender`, -4°). Une seule fois par écran.
class UmNote extends StatelessWidget {
  const UmNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Transform.rotate(
      angle: -4 * 3.141592653589793 / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: UmSpace.s5, vertical: UmSpace.s3),
        decoration: BoxDecoration(
          color: c.lavender,
          borderRadius: BorderRadius.circular(UmRadius.md),
        ),
        child: Text(text, style: UmText.note.copyWith(color: c.brandStrong)),
      ),
    );
  }
}
