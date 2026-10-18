import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

/// Titre de section (« Mon compte », « Badges ») : en-tête pour les lecteurs d'écran.
class UmSectionTitle extends StatelessWidget {
  const UmSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      header: true,
      child: Text(text, style: UmText.h3.copyWith(color: c.ink)),
    );
  }
}
