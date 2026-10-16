import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/features/rides/presentation/ride_map.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

void main() {
  test('le style ne lit que la source vectorielle de l’extrait PMTiles (OpenMapTiles)', () {
    final theme = openMapTilesTheme();
    // Une source sans fournisseur ferait échouer la couche : aucune autre n'est demandée.
    expect(theme.tileSources, {'openmaptiles'});
    expect(theme.layers.where((l) => l.type == vtr.ThemeLayerType.raster), isEmpty);
    // Routes, eau, bâtiments, lieux : le fond reste lisible.
    final layerIds = theme.layers.map((l) => l.id).join(' ');
    expect(layerIds, contains('water'));
    expect(layerIds, contains('road'));
  });

  test('sans PMTILES_URL (tests, développement), pas de fond de carte', () {
    expect(pmtilesUrl, isEmpty);
  });
}
