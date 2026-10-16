import 'package:flutter/material.dart';

import '../../../core/theme/um_theme.dart';

/// Encadré d'information (pénalité annoncée, décision d'un litige) : icône et texte, le
/// sens ne repose jamais sur la couleur seule.
class TrustInfo extends StatelessWidget {
  const TrustInfo({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Container(
      padding: const EdgeInsets.all(UmSpace.s3),
      decoration: BoxDecoration(
        color: c.surfaceTint,
        borderRadius: BorderRadius.circular(UmRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: UmSize.iconMd, color: c.brandStrong),
          ),
          const SizedBox(width: UmSpace.s2),
          Expanded(
            child: Text(text, style: UmText.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}
