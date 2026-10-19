import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../../core/theme/um_theme.dart';
import '../domain/ride.dart';

/// Fond de carte OpenStreetMap : extrait PMTiles vectoriel (schéma OpenMapTiles) servi en
/// statique (docs/couts.md). Sans PMTiles, tuiles raster OpenStreetMap (`RASTER_TILES_URL`,
/// serveur public d'OSM par défaut : usage modéré, attribution affichée).
const pmtilesUrl = String.fromEnvironment('PMTILES_URL');
const rasterTilesUrl = String.fromEnvironment(
  'RASTER_TILES_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// Tuiles raster de secours (désactivées dans les tests : pas de réseau).
final rasterTilesEnabledProvider = Provider<bool>((ref) => true);

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

/// Zone d'une personne dont on ne connaît que le secteur (cercle de 750 m, cahier §4). Une
/// personne proposée ou en attente est « provisoire » (cercle clair, pastille creuse) ; validée,
/// elle passe en plein.
class MapArea {
  const MapArea({
    required this.lat,
    required this.lon,
    required this.name,
    this.provisional = false,
    this.driver = false,
  });

  final double lat;
  final double lon;
  final String name;
  final bool provisional;
  final bool driver;
}

/// Rayon des zones, en mètres : contient le domicile sans le révéler.
const mapAreaRadiusMeters = 750.0;

List<LatLng> _areaCorners(LatLng center) {
  final dLat = mapAreaRadiusMeters / 111320;
  final dLon = mapAreaRadiusMeters / (111320 * math.cos(center.latitude * math.pi / 180));
  return [
    LatLng(center.latitude + dLat, center.longitude - dLon),
    LatLng(center.latitude - dLat, center.longitude + dLon),
  ];
}

/// Carte d'un trajet : tracé, arrêts numérotés dans l'ordre, campus, zones approximatives.
/// `onTap` sert au choix d'un point de rendez-vous ; `pin` montre le point choisi.
class RideMap extends ConsumerStatefulWidget {
  const RideMap({
    super.key,
    required this.stops,
    required this.route,
    required this.semanticLabel,
    this.dashed = false,
    this.pin,
    this.onTap,
    this.live,
    this.areas = const [],
    this.spots = const [],
    this.onSpotTap,
    this.meetingPins = const [],
    this.fitPins = true,
  });

  final List<RideStop> stops;

  /// Personnes dont on ne montre que le secteur (proposées, en attente, autres passagers).
  final List<MapArea> areas;
  final List<(double, double)> route;
  final String semanticLabel;

  /// Tracé approximatif (lignes droites) : pointillés.
  final bool dashed;
  final LatLng? pin;
  final ValueChanged<LatLng>? onTap;

  /// Position du conducteur en direct (trajet en cours).
  final LatLng? live;

  /// Parkings publics et aires de covoiturage, à toucher pour en faire le point de rencontre.
  final List<MeetingSpot> spots;
  final ValueChanged<MeetingSpot>? onSpotTap;

  /// Points de rencontre des passagers (choisis, ou proposés en attente).
  final List<MeetingPin> meetingPins;

  /// Cadrer aussi sur le point choisi et les points de rencontre.
  final bool fitPins;

  @override
  ConsumerState<RideMap> createState() => _RideMapState();
}

class _RideMapState extends ConsumerState<RideMap> {
  final _map = MapController();

  /// Trajet en cours : la carte suit le véhicule jusqu'au prochain geste sur la carte.
  bool _following = false;

  void _followVehicle() {
    final live = widget.live;
    if (live == null) return;
    setState(() => _following = true);
    _map.move(live, UmSize.mapMaxZoom);
  }

  @override
  void didUpdateWidget(RideMap old) {
    super.didUpdateWidget(old);
    final live = widget.live;
    if (live == null) {
      _following = false;
    } else if (_following && live != old.live) {
      // Nouvelle position : la carte se recale sur le véhicule, au zoom choisi.
      _map.move(live, _map.camera.zoom);
    }
  }

  /// Un geste sur la carte (glisser, pincer, double toucher) arrête le suivi.
  void _onMove(MapCamera _, bool hasGesture) {
    if (hasGesture && _following) setState(() => _following = false);
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final RideMap(
      :stops,
      :route,
      :areas,
      :pin,
      :onTap,
      :live,
      :dashed,
      :semanticLabel,
      :spots,
      :onSpotTap,
      :meetingPins,
    ) = widget;
    final line = [for (final (lat, lon) in route) LatLng(lat, lon)];
    final points = [
      ...line,
      for (final s in stops) LatLng(s.lat, s.lon),
      // Les zones entières restent visibles (bords nord-ouest et sud-est du cercle).
      for (final a in [...areas, ...stops.where((s) => s.approximate)])
        for (final corner in _areaCorners(
          LatLng(
            a is MapArea ? a.lat : (a as RideStop).lat,
            a is MapArea ? a.lon : (a as RideStop).lon,
          ),
        ))
          corner,
      if (widget.fitPins) ?pin,
      if (widget.fitPins)
        for (final m in meetingPins) m.point,
    ];
    final exact = stops.where((s) => !s.approximate).toList();
    final zones = [
      for (final s in stops.where((s) => s.approximate))
        MapArea(lat: s.lat, lon: s.lon, name: s.firstName ?? '', driver: s.kind == StopKind.driver),
      ...areas,
    ];

    final map = Semantics(
      label: semanticLabel,
      // La liste des arrêts, sous la carte, porte la même information pour les lecteurs d'écran.
      excludeSemantics: onTap == null,
      child: FlutterMap(
        mapController: _map,
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
          onTap: onTap == null ? null : (_, point) => onTap(point),
          onPositionChanged: live == null ? null : _onMove,
        ),
        children: [
          const BaseMapLayer(),
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
          if (zones.isNotEmpty)
            CircleLayer(
              circles: [
                for (final zone in zones)
                  CircleMarker(
                    point: LatLng(zone.lat, zone.lon),
                    radius: mapAreaRadiusMeters,
                    useRadiusInMeter: true,
                    color: (zone.provisional ? c.inkMuted : c.brand).withValues(
                      alpha: zone.provisional ? 0.10 : 0.18,
                    ),
                    borderColor: zone.provisional ? c.inkMuted : c.brand,
                    borderStrokeWidth: UmSize.routeRing,
                  ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final zone in zones)
                Marker(
                  point: LatLng(zone.lat, zone.lon),
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  child: AreaBadge(area: zone),
                ),
              // Lieux publics sous les arrêts : on voit d'abord le trajet.
              for (final spot in spots)
                Marker(
                  point: LatLng(spot.lat, spot.lon),
                  width: UmSize.tapTarget,
                  height: UmSize.tapTarget,
                  child: SpotBadge(
                    spot: spot,
                    onTap: onSpotTap == null ? null : () => onSpotTap(spot),
                  ),
                ),
              for (final stop in exact)
                Marker(
                  point: LatLng(stop.lat, stop.lon),
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  child: StopBadge(stop: stop),
                ),
              for (final m in meetingPins)
                Marker(
                  point: m.point,
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  alignment: Alignment.topCenter,
                  child: Semantics(
                    label: m.label,
                    child: Icon(
                      m.proposed ? Icons.where_to_vote_outlined : Icons.where_to_vote_rounded,
                      size: UmSize.mapMarker,
                      color: m.proposed ? c.inkMuted : c.success,
                    ),
                  ),
                ),
              if (live != null)
                Marker(
                  point: live,
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.brandStrong,
                      border: Border.all(color: c.onBrand, width: UmSize.routeRing),
                      boxShadow: context.umShadowSoft,
                    ),
                    child: Icon(
                      Icons.navigation_rounded, // distincte de la voiture du point de départ
                      size: UmSize.iconSm,
                      color: c.onBrand,
                    ),
                  ),
                ),
              if (pin != null)
                Marker(
                  point: pin,
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.place_rounded, size: UmSize.mapMarker, color: c.brandStrong),
                ),
            ],
          ),
          const MapAttribution(),
        ],
      ),
    );
    if (live == null) return map;
    // Petit bouton dans le coin bas gauche (l'attribution est à droite) : suivre le véhicule.
    // Actif, il est plein, et la carte suit le véhicule tant qu'on ne la touche pas.
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          left: UmSpace.s3,
          bottom: UmSpace.s3,
          child: Semantics(
            toggled: _following,
            liveRegion: _following,
            hint: _following ? l10n.mapFollowingVehicle : null,
            child: Material(
              color: _following ? c.brandStrong : c.surfaceRaised,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                tooltip: l10n.mapFocusVehicle,
                isSelected: _following,
                constraints: const BoxConstraints(
                  minWidth: UmSize.tapTarget,
                  minHeight: UmSize.tapTarget,
                ),
                icon: Icon(Icons.my_location_rounded, color: c.brandStrong),
                selectedIcon: Icon(Icons.navigation_rounded, color: c.onBrand),
                onPressed: _followVehicle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Point de rencontre d'un passager sur la carte du conducteur.
class MeetingPin {
  const MeetingPin({required this.point, required this.label, this.proposed = false});

  final LatLng point;
  final String label;

  /// Proposé par le conducteur, pas encore accepté : creux.
  final bool proposed;
}

/// Lieu public sur la carte : « P » pour un parking, deux personnes pour une aire de
/// covoiturage. Zone tactile de 48 px autour de la pastille.
class SpotBadge extends StatelessWidget {
  const SpotBadge({super.key, required this.spot, this.onTap});

  final MeetingSpot spot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final carpool = spot.kind == SpotKind.carpool;
    final kind = carpool ? l10n.spotCarpool : l10n.spotParking;
    final size = UmSize.mapMarker * 0.8;
    return Semantics(
      button: onTap != null,
      label: spot.name == null ? kind : '$kind : ${spot.name}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: carpool ? c.success : c.brandStrong,
              borderRadius: BorderRadius.circular(UmRadius.sm),
              border: Border.all(color: c.onBrand, width: UmSize.routeRing),
              boxShadow: context.umShadowSoft,
            ),
            child: carpool
                ? Icon(Icons.people_alt_rounded, size: UmSize.iconSm, color: c.onBrand)
                : Text('P', style: UmText.label.copyWith(color: c.onBrand)),
          ),
        ),
      ),
    );
  }
}

/// Pastille d'une zone : voiture (conducteur) ou initiale ; creuse tant que c'est provisoire.
class AreaBadge extends StatelessWidget {
  const AreaBadge({super.key, required this.area, this.size = UmSize.mapMarker});

  final MapArea area;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.umColors;
    final (background, foreground) = area.provisional
        ? (c.surfaceRaised, c.inkMuted)
        : (c.brand, c.onBrand);
    final initial = area.name.isEmpty ? '?' : area.name.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(
            color: area.provisional ? c.inkMuted : c.onBrand,
            width: UmSize.routeRing,
          ),
          boxShadow: context.umShadowSoft,
        ),
        child: area.driver
            ? Icon(Icons.directions_car_rounded, size: UmSize.iconSm, color: foreground)
            : Text(initial, style: UmText.label.copyWith(color: foreground)),
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
          // Au retour, l'arrêt du conducteur est l'arrivée (dernier arrêt) : un drapeau.
          StopKind.driver => Icon(
            stop.order > 0 ? Icons.sports_score_rounded : Icons.directions_car_rounded,
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

/// Mention des données (licence ODbL d'OpenStreetMap), lisible et sans débordement même
/// avec un texte agrandi.
/// Fond de carte : PMTiles vectoriel s'il est configuré, sinon tuiles raster d'OpenStreetMap
/// (aussi en attendant le chargement du PMTiles), rien dans les tests.
class BaseMapLayer extends ConsumerWidget {
  const BaseMapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = ref.watch(mapBackgroundProvider).value;
    if (background != null) {
      return VectorTileLayer(
        tileProviders: TileProviders({_source: background.tiles}),
        // Pas de maximumZoom : au-delà du zoom 14 de l'extrait, les tuiles sont agrandies
        // au lieu de disparaître (écran du point de rendez-vous, zoom 16).
        theme: background.theme,
        // Rendu vectoriel direct : net à tout zoom, sans images intermédiaires annulées
        // (et signalées comme erreurs) quand on quitte la carte.
        layerMode: VectorTileLayerMode.vector,
      );
    }
    if (!ref.watch(rasterTilesEnabledProvider)) return const SizedBox.shrink();
    return TileLayer(
      urlTemplate: rasterTilesUrl,
      // Exigé par la politique d'usage des tuiles OSM.
      userAgentPackageName: 'fr.unimoov.unimoov',
      maxNativeZoom: 19,
    );
  }
}

/// « © OpenStreetMap », dès qu'un fond de carte est affiché.
class MapAttribution extends ConsumerWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.umColors;
    final shown =
        ref.watch(mapBackgroundProvider).value != null || ref.watch(rasterTilesEnabledProvider);
    if (!shown) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(UmSpace.s1),
        padding: const EdgeInsets.symmetric(horizontal: UmSpace.s2, vertical: UmSpace.s1),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(UmRadius.sm),
        ),
        child: Text('© OpenStreetMap', style: UmText.caption.copyWith(color: c.ink)),
      ),
    );
  }
}
