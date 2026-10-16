import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../../core/theme/um_theme.dart';
import '../domain/ride.dart';

/// Fond de carte OpenStreetMap : extrait PMTiles vectoriel (schéma OpenMapTiles) servi en
/// statique (docs/couts.md). Sans URL (développement, tests), la carte montre tracé et
/// arrêts sur un fond uni.
const pmtilesUrl = String.fromEnvironment('PMTILES_URL');

/// Source des tuiles dans le style OpenMapTiles.
const _source = 'openmaptiles';

class MapBackground {
  const MapBackground(this.tiles, this.theme);

  final VectorTileProvider tiles;
  final vtr.Theme theme;
}

/// Style clair OpenMapTiles fourni par vector_tile_renderer, sans la couche de relief
/// ombré (un fichier raster à part, absent) : seule notre source vectorielle est lue.
vtr.Theme openMapTilesTheme() => vtr.ProvidedThemes.lightTheme().copyWith(
  types: {...vtr.ThemeLayerType.values}..remove(vtr.ThemeLayerType.raster),
);

final mapBackgroundProvider = FutureProvider<MapBackground?>((ref) async {
  if (pmtilesUrl.isEmpty) return null;
  try {
    final tiles = await PmTilesVectorTileProvider.fromSource(pmtilesUrl);
    return MapBackground(tiles, openMapTilesTheme());
  } on Object {
    // Fond indisponible : la carte reste utilisable sans lui.
    return null;
  }
});

/// Carte d'un trajet : tracé, arrêts numérotés dans l'ordre, campus. `onTap` sert au choix
/// d'un point de rendez-vous ; `pin` montre le point choisi.
class RideMap extends ConsumerWidget {
  const RideMap({
    super.key,
    required this.stops,
    required this.route,
    required this.semanticLabel,
    this.dashed = false,
    this.pin,
    this.onTap,
  });

  final List<RideStop> stops;
  final List<(double, double)> route;
  final String semanticLabel;

  /// Tracé approximatif (lignes droites) : pointillés.
  final bool dashed;
  final LatLng? pin;
  final ValueChanged<LatLng>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.umColors;
    final background = ref.watch(mapBackgroundProvider).value;
    final line = [for (final (lat, lon) in route) LatLng(lat, lon)];
    final points = [...line, for (final s in stops) LatLng(s.lat, s.lon), ?pin];

    return Semantics(
      label: semanticLabel,
      // La liste des arrêts, sous la carte, porte la même information pour les lecteurs d'écran.
      excludeSemantics: onTap == null,
      child: FlutterMap(
        options: MapOptions(
          backgroundColor: c.surfaceTint,
          initialCameraFit: points.length < 2
              ? null
              : CameraFit.coordinates(
                  coordinates: points,
                  padding: const EdgeInsets.all(UmSpace.s7),
                  maxZoom: UmSize.mapMaxZoom,
                ),
          initialCenter: points.isEmpty ? const LatLng(45.9195, 6.158) : points.first,
          initialZoom: UmSize.mapMaxZoom - 1,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: onTap == null ? null : (_, point) => onTap!(point),
        ),
        children: [
          if (background != null)
            VectorTileLayer(
              tileProviders: TileProviders({_source: background.tiles}),
              theme: background.theme,
              maximumZoom: background.tiles.maximumZoom.toDouble(),
            ),
          if (line.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: line,
                  strokeWidth: UmSize.routeStroke,
                  color: c.brand,
                  pattern: dashed
                      ? StrokePattern.dashed(segments: const [UmSpace.s3, UmSpace.s2])
                      : const StrokePattern.solid(),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final stop in stops)
                Marker(
                  point: LatLng(stop.lat, stop.lon),
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  child: StopBadge(stop: stop),
                ),
              if (pin != null)
                Marker(
                  point: pin!,
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.place_rounded, size: UmSize.mapMarker, color: c.brandStrong),
                ),
            ],
          ),
          if (background != null)
            const SimpleAttributionWidget(source: Text('OpenStreetMap, OpenMapTiles')),
        ],
      ),
    );
  }
}

/// Pastille d'arrêt : voiture (conducteur), numéro (passager), école (campus). La même
/// pastille sert sur la carte et dans la liste, pour relier les deux.
class StopBadge extends StatelessWidget {
  const StopBadge({super.key, required this.stop, this.size = UmSize.mapMarker});

  final RideStop stop;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final (background, foreground, border) = switch (stop.kind) {
      StopKind.driver => (c.brand, c.onBrand, null),
      StopKind.passenger => (c.surfaceRaised, c.brandStrong, c.brandStrong),
      StopKind.campus => (c.brandStrong, c.onBrand, null),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: border == null ? null : Border.all(color: border, width: UmSize.routeRing),
          boxShadow: context.umShadowSoft,
        ),
        child: switch (stop.kind) {
          StopKind.driver => Icon(
            Icons.directions_car_rounded,
            size: UmSize.iconSm,
            color: foreground,
          ),
          StopKind.campus => Icon(Icons.school_rounded, size: UmSize.iconSm, color: foreground),
          StopKind.passenger => Text(
            '${stop.order}',
            style: UmText.label.copyWith(color: foreground),
          ),
        },
      ),
    );
  }
}
