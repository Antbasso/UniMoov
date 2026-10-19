import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Préférences d'affichage gardées sur le téléphone (aucune donnée envoyée au serveur).
abstract interface class PrefsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecurePrefsStore implements PrefsStore {
  const SecurePrefsStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

/// Pour les tests et la démo : rien n'est écrit sur l'appareil.
class MemoryPrefsStore implements PrefsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final prefsStoreProvider = Provider<PrefsStore>((ref) => const SecurePrefsStore());

class Appearance {
  const Appearance({this.themeMode = ThemeMode.system, this.reduceMotion = false});

  final ThemeMode themeMode;

  /// Animations coupées dans l'app, en plus du réglage d'accessibilité du téléphone.
  final bool reduceMotion;

  Appearance copyWith({ThemeMode? themeMode, bool? reduceMotion}) => Appearance(
    themeMode: themeMode ?? this.themeMode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

/// Thème (automatique, clair, sombre) et animations réduites, choisis dans le profil.
class AppearanceController extends Notifier<Appearance> {
  static const _themeKey = 'prefs.theme';
  static const _motionKey = 'prefs.reduceMotion';

  PrefsStore get _store => ref.read(prefsStoreProvider);

  @override
  Appearance build() {
    _load();
    return const Appearance();
  }

  Future<void> _load() async {
    try {
      final theme = await _store.read(_themeKey);
      final motion = await _store.read(_motionKey);
      if (!ref.mounted) return;
      state = Appearance(
        themeMode: ThemeMode.values.where((m) => m.name == theme).firstOrNull ?? ThemeMode.system,
        reduceMotion: motion == 'true',
      );
    } on Object {
      // Stockage illisible : réglages par défaut.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.write(_themeKey, mode.name);
  }

  Future<void> setReduceMotion(bool on) async {
    state = state.copyWith(reduceMotion: on);
    await _store.write(_motionKey, '$on');
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(
  AppearanceController.new,
);
