import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_messages.dart';
import '../../../l10n/app_localizations.dart';
import 'me_controller.dart';
import 'person_avatar.dart';

/// Photo de profil : en choisir une (galerie), en prendre une, ou la retirer.
Future<void> showPhotoSheet(BuildContext context, WidgetRef ref, {required bool hasPhoto}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.photoFromGallery),
            onTap: () => Navigator.of(sheet).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.photoFromCamera),
            onTap: () => Navigator.of(sheet).pop('camera'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.photoRemove),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  final me = ref.read(meProvider.notifier);
  try {
    if (choice == 'remove') {
      await me.removePhoto();
    } else {
      final bytes = await ref.read(photoPickerProvider)(camera: choice == 'camera');
      if (bytes == null) return;
      await me.setPhoto(bytes, imageContentType(bytes));
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoSaved)));
  } on ApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(l10n, error.code))));
  } on Object {
    // Accès aux photos refusé ou sélecteur indisponible.
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoUnavailable)));
  }
}
