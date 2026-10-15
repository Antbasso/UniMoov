import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

enum UmButtonVariant { primary, secondary, ghost }

/// Bouton d'action (docs/design-system/components/Button.md) : 48 px minimum,
/// rayon `radius-md` (ou pilule), anneau de focus de 3 px décalé de 2 px.
class UmButton extends StatefulWidget {
  const UmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = UmButtonVariant.primary,
    this.icon,
    this.pill = false,
    this.expand = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final UmButtonVariant variant;
  final IconData? icon;
  final bool pill;
  final bool expand;

  /// Action en cours : indicateur à la place de l'icône, appuis ignorés, libellé conservé.
  final bool loading;

  @override
  State<UmButton> createState() => _UmButtonState();
}

class _UmButtonState extends State<UmButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final radius = widget.pill ? UmRadius.pill : UmRadius.md;
    final enabled = widget.onPressed != null;
    final (background, foreground, pressed, border) = switch (widget.variant) {
      UmButtonVariant.primary => (c.brand, c.onBrand, c.brandStrong, null),
      UmButtonVariant.secondary => (c.surfaceRaised, c.brandStrong, c.lavender, c.borderControl),
      UmButtonVariant.ghost => (Colors.transparent, c.brandStrong, c.surfaceTint, null),
    };

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(UmSize.tapTarget, UmSize.tapTarget)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: UmSpace.s5, vertical: UmSpace.s3),
      ),
      textStyle: WidgetStatePropertyAll(UmText.button),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            widget.variant == UmButtonVariant.primary && states.contains(WidgetState.pressed)
            ? c.surface
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed) ? pressed : background,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      side: WidgetStatePropertyAll(
        border == null ? BorderSide.none : BorderSide(color: border, width: UmSize.controlBorder),
      ),
      animationDuration: UmMotion.fast,
    );

    final leading = widget.loading
        ? SizedBox.square(
            dimension: UmSize.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: UmSize.iconStroke,
              color: widget.variant == UmButtonVariant.primary ? c.onBrand : c.brandStrong,
            ),
          )
        : (widget.icon == null ? null : Icon(widget.icon, size: UmSize.iconMd));

    final child = leading == null
        ? Text(widget.label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: UmSpace.s2),
              Text(widget.label),
            ],
          );

    // Pendant le chargement, le bouton garde son apparence active (pas d'opacité réduite).
    final button = Opacity(
      opacity: enabled ? 1 : UmSize.disabledOpacity,
      child: CustomPaint(
        foregroundPainter: _FocusRingPainter(visible: _focused, color: c.focus, radius: radius),
        child: TextButton(
          onPressed: widget.loading ? null : widget.onPressed,
          onFocusChange: (focused) => setState(() => _focused = focused),
          style: style,
          child: child,
        ),
      ),
    );
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Anneau de focus dessiné autour du bouton, sans modifier sa taille (outline CSS).
class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.visible, required this.color, required this.radius});

  final bool visible;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    const inset = UmSize.focusOffset + UmSize.focusRing / 2;
    final rect = (Offset.zero & size).inflate(inset);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius + inset));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = UmSize.focusRing
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.visible != visible || old.color != color || old.radius != radius;
}
