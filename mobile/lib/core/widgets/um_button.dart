import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

enum UmButtonVariant { primary, secondary, ghost }

/// Bouton d'action (docs/design-system/components/Button.md) : 48 px minimum,
/// rayon `radius-md` (ou pilule), anneau de focus de 3 px.
class UmButton extends StatelessWidget {
  const UmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = UmButtonVariant.primary,
    this.icon,
    this.pill = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final UmButtonVariant variant;
  final IconData? icon;
  final bool pill;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final (background, foreground, pressed, border) = switch (variant) {
      UmButtonVariant.primary => (c.brand, c.onBrand, c.brandStrong, null),
      UmButtonVariant.secondary => (c.surfaceRaised, c.brandStrong, c.lavender, c.borderControl),
      UmButtonVariant.ghost => (Colors.transparent, c.brandStrong, c.surfaceTint, null),
    };

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: UmSpace.s5, vertical: UmSpace.s3),
      ),
      textStyle: WidgetStatePropertyAll(UmText.label.copyWith(fontSize: 16, height: 1.5)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => variant == UmButtonVariant.primary && states.contains(WidgetState.pressed)
            ? c.surface
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed) ? pressed : background,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pill ? UmRadius.pill : UmRadius.md),
        ),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return BorderSide(color: c.focus, width: 3);
        return border == null ? BorderSide.none : BorderSide(color: border, width: 2);
      }),
      animationDuration: const Duration(milliseconds: 150),
    );

    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: UmSpace.s2),
              Text(label),
            ],
          );

    final button = Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: TextButton(onPressed: onPressed, style: style, child: child),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
