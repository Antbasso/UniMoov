import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

/// Bloc icône + légende (docs/design-system/components/Benefit.md).
class UmBenefit extends StatelessWidget {
  const UmBenefit({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: c.brandStrong),
          const SizedBox(height: UmSpace.s2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: UmText.bodySm.copyWith(color: c.ink),
          ),
        ],
      ),
    );
  }
}

/// Rangée de bénéfices : toujours trois, en grille égale.
class UmBenefitRow extends StatelessWidget {
  const UmBenefitRow({super.key, required this.benefits})
    : assert(benefits.length == 3, 'Les bénéfices vont toujours par trois');

  final List<UmBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < benefits.length; i++) ...[
          if (i > 0) const SizedBox(width: UmSpace.s4),
          Expanded(child: benefits[i]),
        ],
      ],
    );
  }
}
