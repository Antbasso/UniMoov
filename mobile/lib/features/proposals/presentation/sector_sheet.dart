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
    final (lat, lon) = person.sector!;
    final center = LatLng(lat, lon);
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
            ClipRRect(
              borderRadius: BorderRadius.circular(UmRadius.md),
              child: SizedBox(
                height: UmSize.mapHeight,
                child: Semantics(
                  label: l10n.sectorMapLabel(person.firstName),
                  excludeSemantics: true,
                  child: FlutterMap(
                    options: MapOptions(
                      backgroundColor: c.surfaceTint,
                      initialCameraFit: CameraFit.coordinates(
                        coordinates: [center, _campus],
                        padding: const EdgeInsets.all(UmSpace.s7),
                        maxZoom: 14,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                              decoration: BoxDecoration(
                                color: c.brandStrong,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.school_rounded,
                                size: UmSize.iconSm,
                                color: c.onBrand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const MapAttribution(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
