import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

typedef GeoPoint = ({double lat, double lon, DateTime at});

/// Position du téléphone, uniquement pendant un trajet en cours (cahier §9, §14).
abstract interface class LocationService {
  Future<LocationAccess> status();

  /// Demande système, après l'écran d'explication.
  Future<LocationAccess> request();

  /// Réglages de l'application (permission refusée définitivement).
  Future<void> openSettings();

  /// Positions environ toutes les 5 s, y compris écran éteint (notification permanente sur
  /// Android). `notificationTitle` et `notificationText` : textes de cette notification.
  Stream<GeoPoint> positions({required String notificationTitle, required String notificationText});
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  LocationAccess _map(LocationPermission p) => switch (p) {
    LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    _ => LocationAccess.denied,
  };

  @override
  Future<LocationAccess> status() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();

  @override
  Stream<GeoPoint> positions({
    required String notificationTitle,
    required String notificationText,
  }) {
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        intervalDuration: const Duration(seconds: 5),
        // Économie de batterie : peu de mises à jour à l'arrêt.
        distanceFilter: 10,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          enableWakeLock: true,
        ),
      ),
      TargetPlatform.iOS => AppleSettings(
        distanceFilter: 10,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: true,
      ),
      _ => const LocationSettings(distanceFilter: 10),
    };
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => (lat: p.latitude, lon: p.longitude, at: p.timestamp));
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
