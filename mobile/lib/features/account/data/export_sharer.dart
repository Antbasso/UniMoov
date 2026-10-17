import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Remet le fichier exporté à l'utilisateur (enregistrer, envoyer) par la feuille de partage
/// du système ; remplaçable en test.
abstract interface class ExportSharer {
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String subject,
    Rect? origin,
  });
}

class SystemExportSharer implements ExportSharer {
  const SystemExportSharer();

  @override
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String subject,
    Rect? origin,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json')],
      fileNameOverrides: [fileName],
      subject: subject,
      // Tablettes iOS : la feuille s'ouvre depuis le bouton.
      sharePositionOrigin: origin,
    ),
  );
}

final exportSharerProvider = Provider<ExportSharer>((ref) => const SystemExportSharer());
