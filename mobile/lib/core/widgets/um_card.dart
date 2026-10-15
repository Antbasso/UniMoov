import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

/// Surface flottante (docs/design-system/components/Card.md) : titre `h3`, texte `body-sm`
/// en `ink-muted`, ou contenu libre.
class UmCard extends StatelessWidget {
  const UmCard({super.key, this.title, this.body, this.child})
    : frame = false,
      assert(title != null || body != null || child != null, 'Carte vide');

  /// Cadre `lavender` réservé à un code ou une image à scanner (fond toujours clair).
  const UmCard.frame({super.key, required Widget this.child})
    : frame = true,
      title = null,
      body = null;

  final String? title;
  final String? body;

  /// Contenu libre, sous le titre et le texte. Une seule action principale par carte.
  final Widget? child;
  final bool frame;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    if (frame) {
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
    return Container(
      padding: const EdgeInsets.all(UmSpace.s5),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(UmRadius.lg),
        boxShadow: context.umShadowSoft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(title!, style: UmText.h3.copyWith(color: c.ink)),
            ),
          if (title != null && body != null) const SizedBox(height: UmSpace.s2),
          if (body != null) Text(body!, style: UmText.bodySm.copyWith(color: c.inkMuted)),
          if (child != null && (title != null || body != null)) const SizedBox(height: UmSpace.s4),
          ?child,
        ],
      ),
    );
  }
}
