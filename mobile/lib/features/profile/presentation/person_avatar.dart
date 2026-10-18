import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'me_controller.dart';

/// Photo d'une personne si elle en a une (chargée avec le jeton), sinon son initiale.
class PersonAvatar extends ConsumerWidget {
  const PersonAvatar({super.key, required this.name, this.photoUrl, this.size = UmSize.avatar});

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = photoUrl;
    final bytes = url == null ? null : ref.watch(photoProvider(url)).value;
    return UmAvatar(name: name, size: size, image: bytes == null ? null : MemoryImage(bytes));
  }
}

/// Choix d'une photo (galerie ou appareil), réduite à 512 px en JPEG avant l'envoi. Remplaçable
/// dans les tests.
typedef PhotoPicker = Future<Uint8List?> Function({required bool camera});

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ({required bool camera}) async {
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    return file?.readAsBytes();
  },
);

/// Type d'une image d'après ses premiers octets (PNG sinon JPEG, comme le vérifie le serveur).
String imageContentType(Uint8List bytes) =>
    bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47
    ? 'image/png'
    : 'image/jpeg';
