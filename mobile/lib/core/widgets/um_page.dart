import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

/// Gabarit d'écran : marges `space-6`, titre `h1` annoncé comme en-tête, contenu défilant
/// et actions en pied. Garde tous les écrans alignés sur le design system.
class UmPage extends StatelessWidget {
  const UmPage({
    super.key,
    this.title,
    this.intro,
    this.overline,
    required this.children,
    this.footer = const [],
    this.appBar,
  });

  final String? title;
  final String? intro;

  /// Petite ligne au-dessus du titre (progression d'étape).
  final String? overline;
  final List<Widget> children;
  final List<Widget> footer;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(UmSpace.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overline != null) ...[
                      Text(overline!, style: UmText.label.copyWith(color: c.brandStrong)),
                      const SizedBox(height: UmSpace.s2),
                    ],
                    if (title != null) ...[
                      Semantics(
                        header: true,
                        child: Text(title!, style: UmText.h1.copyWith(color: c.ink)),
                      ),
                      const SizedBox(height: UmSpace.s3),
                    ],
                    if (intro != null) ...[
                      Text(intro!, style: UmText.body.copyWith(color: c.inkMuted)),
                      const SizedBox(height: UmSpace.s5),
                    ],
                    ...children,
                  ],
                ),
              ),
            ),
            if (footer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < footer.length; i++) ...[
                      if (i > 0) const SizedBox(height: UmSpace.s2),
                      footer[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Message d'erreur en bloc : mot + icône, jamais la couleur seule, annoncé aux lecteurs d'écran.
class UmErrorText extends StatelessWidget {
  const UmErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(UmSpace.s3),
        decoration: BoxDecoration(
          color: c.dangerSoft,
          borderRadius: BorderRadius.circular(UmRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: UmSize.iconMd, color: c.danger),
            const SizedBox(width: UmSpace.s2),
            Expanded(
              child: Text(message, style: UmText.bodySm.copyWith(color: c.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
