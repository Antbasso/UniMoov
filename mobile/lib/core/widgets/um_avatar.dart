import 'package:flutter/material.dart';

import '../theme/um_theme.dart';

/// Photo de profil ronde ; sans photo, l'initiale du prénom sur fond lavande. Décorative :
/// le prénom est toujours écrit à côté.
class UmAvatar extends StatelessWidget {
  const UmAvatar({super.key, required this.name, this.image, this.size = UmSize.avatar});

  final String name;
  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.lavender,
          shape: BoxShape.circle,
          image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        child: image != null
            ? null
            : Text(
                initial,
                style: (size >= UmSize.avatarLg ? UmText.h2 : UmText.button).copyWith(
                  color: c.brandStrong,
                ),
              ),
      ),
    );
  }
}
