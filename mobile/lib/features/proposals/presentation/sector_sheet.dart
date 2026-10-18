import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/um_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../rides/presentation/ride_map.dart';
import '../domain/proposal.dart';

/// Rayon du cercle affiché autour du centre du secteur (cellule de 500 m) : le domicile est
/// toujours dedans, sans pouvoir être deviné (comme une annonce immobilière, cahier §4).
const sectorRadiusMeters = 750.0;

const _campus = LatLng(45.9195, 6.158);

Future<void> showSectorSheet(BuildContext context, PublicPerson person) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SectorSheet(person: person),
    );

/// Zone approximative d'une personne avant acceptation mutuelle : un cercle, jamais l'adresse.
class SectorSheet extends StatelessWidget {
  const SectorSheet({required this.person, super.key});

  final PublicPerson person;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(UmSpace.s6, 0, UmSpace.s6, UmSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.sectorTitle(person.firstName),
                style: UmText.h2.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: UmSpace.s2),
            Text(l10n.sectorBody, style: UmText.bodySm.copyWith(color: c.inkMuted)),
            const SizedBox(height: UmSpace.s4),
            SectorMap(person: person, height: UmSize.mapHeight, interactive: true),
          ],
        ),
      ),
    );
  }
}

/// Coins nord-ouest et sud-est du cercle du secteur.
List<LatLng> _circleBounds(LatLng center) {
  final dLat = sectorRadiusMeters / 111320;
  final dLon = sectorRadiusMeters / (111320 * math.cos(center.latitude * math.pi / 180));
  return [
    LatLng(center.latitude + dLat, center.longitude - dLon),
    LatLng(center.latitude - dLat, center.longitude + dLon),
  ];
}

/// Carte du secteur : cercle de 750 m autour du centre, et le campus pour se repérer. Dans une
/// fiche (`interactive: false`), elle est figée et s'agrandit au toucher.
class SectorMap extends StatelessWidget {
  const SectorMap({
    required this.person,
    this.height = UmSize.sectorMiniMap,
    this.interactive = false,
    super.key,
  });

  final PublicPerson person;
  final double height;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.umColors;
    final (lat, lon) = person.sector!;
    final center = LatLng(lat, lon);
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(UmRadius.md),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            backgroundColor: c.surfaceTint,
            // Mini-carte : le cercle remplit la carte ; agrandie, le campus aussi pour se repérer.
            initialCameraFit: CameraFit.coordinates(
              coordinates: [..._circleBounds(center), if (interactive) _campus],
              padding: const EdgeInsets.all(UmSpace.s4),
              maxZoom: 15,
            ),
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            const BaseMapLayer(),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: sectorRadiusMeters,
                  useRadiusInMeter: true,
                  color: c.brand.withValues(alpha: 0.22),
                  borderColor: c.brandStrong,
                  borderStrokeWidth: UmSize.routeRing,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _campus,
                  width: UmSize.mapMarker,
                  height: UmSize.mapMarker,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c.brandStrong, shape: BoxShape.circle),
                    child: Icon(Icons.school_rounded, size: UmSize.iconSm, color: c.onBrand),
                  ),
                ),
              ],
            ),
            const MapAttribution(),
          ],
        ),
      ),
    );
    if (interactive) {
      return Semantics(
        label: l10n.sectorMapLabel(person.firstName),
        excludeSemantics: true,
        child: map,
      );
    }
    // Mini-carte d'une fiche : toucher pour l'agrandir.
    return Semantics(
      button: true,
      label: '${l10n.sectorMapLabel(person.firstName)}. ${l10n.sectorEnlarge}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showSectorSheet(context, person),
        child: AbsorbPointer(child: map),
      ),
    );
  }
}
