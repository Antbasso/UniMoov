import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

/// Surface flottante (docs/design-system/components/Card.md).
class UmCard extends StatelessWidget {
  const UmCard({super.key, required this.child}) : frame = false;

  /// Cadre `lavender` réservé à un code ou une image à scanner (fond toujours clair).
  const UmCard.frame({super.key, required this.child}) : frame = true;

  final Widget child;
  final bool frame;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    if (!frame) {
      return Container(
        padding: const EdgeInsets.all(UmSpace.s5),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(UmRadius.lg),
          boxShadow: context.umShadowSoft,
        ),
        child: child,
      );
    }
    return Container(
      padding: const EdgeInsets.all(UmSpace.s3),
      decoration: BoxDecoration(
        color: c.lavender,
        borderRadius: BorderRadius.circular(UmRadius.lg),
        boxShadow: context.umShadowSoft,
      ),
      child: Container(
        padding: const EdgeInsets.all(UmSpace.s4),
        decoration: BoxDecoration(
          // Contenu à scanner : fond clair même en thème sombre.
          color: UmColorTokens.light.surfaceRaised,
          borderRadius: BorderRadius.circular(UmRadius.md),
        ),
        child: child,
      ),
    );
  }
}
