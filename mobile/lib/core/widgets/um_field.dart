import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/um_theme.dart';

/// Champ de saisie (docs/design-system/components/Field.md) : libellé toujours visible,
/// bordure 2 px `border-control`, erreur préfixée par le mot « Erreur ».
/// L'aide et l'erreur sont rattachées au champ : les lecteurs d'écran les annoncent avec lui.
class UmField extends StatefulWidget {
  const UmField({
    super.key,
    required this.label,
    this.controller,
    this.placeholder,
    this.help,
    this.error,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final String? placeholder;
  final String? help;
  final String? error;
  final TextInputType? keyboardType;

  /// Mot de passe : texte masqué, avec un bouton pour l'afficher.
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<UmField> createState() => _UmFieldState();
}

class _UmFieldState extends State<UmField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final l10n = AppLocalizations.of(context);
    final prefix = l10n.fieldErrorPrefix;
    final error = widget.error;
    final errorText = error == null || error.startsWith(prefix) ? error : '$prefix : $error';

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(UmRadius.sm),
      borderSide: BorderSide(color: color, width: width),
    );
    final messageStyle = UmText.caption;

    return Opacity(
      opacity: widget.enabled ? 1 : UmSize.disabledOpacity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: UmSize.fieldMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Annoncé par le champ lui-même (label sémantique) : pas de double lecture.
            ExcludeSemantics(
              child: Text(widget.label, style: UmText.label.copyWith(color: c.ink)),
            ),
            const SizedBox(height: UmSpace.s1),
            Semantics(
              label: widget.label,
              child: TextField(
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                obscureText: _obscured,
                enabled: widget.enabled,
                onChanged: widget.onChanged,
                autofillHints: widget.autofillHints,
                style: UmText.body.copyWith(color: c.ink),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: UmText.body.copyWith(color: c.inkMuted),
                  helperText: widget.help,
                  helperStyle: messageStyle.copyWith(color: c.inkMuted),
                  helperMaxLines: 3,
                  errorText: errorText,
                  errorStyle: messageStyle.copyWith(color: c.danger),
                  errorMaxLines: 3,
                  filled: true,
                  fillColor: c.surfaceRaised,
                  constraints: const BoxConstraints(minHeight: UmSize.tapTarget),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: UmSpace.s4,
                    vertical: UmSpace.s3,
                  ),
                  enabledBorder: border(c.borderControl, UmSize.controlBorder),
                  disabledBorder: border(c.borderControl, UmSize.controlBorder),
                  focusedBorder: border(c.focus, UmSize.focusRing),
                  // En erreur, la bordure reste rouge même avec le focus (plus épaisse).
                  errorBorder: border(c.danger, UmSize.controlBorder),
                  focusedErrorBorder: border(c.danger, UmSize.focusRing),
                  suffixIcon: widget.obscureText
                      ? IconButton(
                          tooltip: _obscured ? l10n.fieldShowPassword : l10n.fieldHidePassword,
                          icon: Icon(
                            _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: UmSize.iconMd,
                            color: c.brandStrong,
                          ),
                          onPressed: () => setState(() => _obscured = !_obscured),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
