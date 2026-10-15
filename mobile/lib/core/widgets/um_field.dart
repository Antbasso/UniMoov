import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/um_theme.dart';

/// Champ de saisie (docs/design-system/components/Field.md) : libellé toujours visible,
/// bordure 2 px `border-control`, erreur préfixée par le mot « Erreur ».
class UmField extends StatelessWidget {
  const UmField({
    super.key,
    required this.label,
    this.controller,
    this.placeholder,
    this.help,
    this.error,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final String? placeholder;
  final String? help;
  final String? error;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final prefix = AppLocalizations.of(context).fieldErrorPrefix;
    final errorText = error == null || error!.startsWith(prefix) ? error : '$prefix : $error';
    final borderColor = errorText == null ? c.borderControl : c.danger;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(UmRadius.sm),
      borderSide: BorderSide(color: color, width: width),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: UmText.label.copyWith(color: c.ink)),
          const SizedBox(height: UmSpace.s1),
          // Le libellé visible est aussi annoncé par les lecteurs d'écran.
          Semantics(
            label: label,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onChanged: onChanged,
              autofillHints: autofillHints,
              style: UmText.body.copyWith(color: c.ink),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: UmText.body.copyWith(color: c.inkMuted),
                filled: true,
                fillColor: c.surfaceRaised,
                constraints: const BoxConstraints(minHeight: 48),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: UmSpace.s4,
                  vertical: UmSpace.s3,
                ),
                enabledBorder: border(borderColor, 2),
                focusedBorder: border(c.focus, 3),
                border: border(borderColor, 2),
              ),
            ),
          ),
          if (errorText != null || help != null) ...[
            const SizedBox(height: UmSpace.s1),
            Text(
              errorText ?? help!,
              style: UmText.caption.copyWith(color: errorText != null ? c.danger : c.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
