import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les deux jetons sont lus et écrits ensemble', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureTokenStorage();
    expect(await storage.read(), isNull);
    await storage.write(const AuthTokens(accessToken: 'a1', refreshToken: 'r1'));
    final tokens = await storage.read();
    expect((tokens?.accessToken, tokens?.refreshToken), ('a1', 'r1'));
    await storage.clear();
    expect(await storage.read(), isNull);
  });

  test('ancien format (deux clés) : session reprise puis réécrite d’un bloc', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth.accessToken': 'a0',
      'auth.refreshToken': 'r0',
    });
    final storage = SecureTokenStorage();
    expect((await storage.read())?.refreshToken, 'r0');
    final raw = await const FlutterSecureStorage().readAll();
    expect(raw.keys, ['auth.session']);
  });

  test('valeur illisible : session effacée plutôt qu’une erreur au lancement', () async {
    FlutterSecureStorage.setMockInitialValues({'auth.session': 'pas du json'});
    final storage = SecureTokenStorage();
    expect(await storage.read(), isNull);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });
}
