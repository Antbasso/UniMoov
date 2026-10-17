import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';

void main() {
  test('version publiée : HTTPS exigé pour l’API et le fond de carte', () {
    expect(
      () => assertSecureEndpoints(apiBaseUrl: 'http://10.0.2.2:3000', pmtilesUrl: ''),
      throwsStateError,
    );
    expect(
      () => assertSecureEndpoints(
        apiBaseUrl: 'https://api.uni-moov.fr',
        pmtilesUrl: 'http://tiles.local/annecy.pmtiles',
      ),
      throwsStateError,
    );
    assertSecureEndpoints(
      apiBaseUrl: 'https://api.uni-moov.fr',
      pmtilesUrl: 'https://api.uni-moov.fr/tiles/annecy.pmtiles',
    );
    assertSecureEndpoints(apiBaseUrl: 'https://api.uni-moov.fr', pmtilesUrl: '');
  });
}
