import 'dart:io';
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

  /// Fichier écrit dans un dossier temporaire à part, effacé dès la feuille fermée : les
  /// données exportées ne restent pas sur le téléphone (`XFile.fromData` les y laisserait).
  @override
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String subject,
    Rect? origin,
  }) async {
    final dir = await Directory.systemTemp.createTemp('uni-moov-export-');
    try {
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: subject,
          // Tablettes iOS : la feuille s'ouvre depuis le bouton.
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      await dir.delete(recursive: true);
    }
  }
}

final exportSharerProvider = Provider<ExportSharer>((ref) => const SystemExportSharer());
