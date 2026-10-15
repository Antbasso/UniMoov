import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimoov/core/api/api_client.dart';
import 'package:unimoov/core/storage/token_storage.dart';
import 'package:unimoov/features/auth/data/auth_api.dart';
import 'package:unimoov/features/auth/domain/auth_tokens.dart';
import 'package:unimoov/features/auth/presentation/session_controller.dart';
import 'package:unimoov/features/auth/presentation/signup_controller.dart';

import '../../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStorage storage;
  late ProviderContainer container;

  ProviderContainer create() => ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authApiProvider.overrideWithValue(backend),
    ],
  );

  setUp(() {
    backend = FakeBackend();
    storage = MemoryTokenStorage();
    container = create();
  });
  tearDown(() => container.dispose());

  group('SessionController', () {
    test('restaure une session stockée au lancement', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      expect(await container.read(sessionProvider.future), SessionStatus.signedIn);
    });

    test('sans jetons : déconnecté', () async {
      expect(await container.read(sessionProvider.future), SessionStatus.signedOut);
    });

    test('signOut efface les jetons même hors ligne', () async {
      storage.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await container.read(sessionProvider.future);
      backend.failNext = const ApiException('network_error', '');
      await container.read(sessionProvider.notifier).signOut();
      expect(storage.tokens, isNull);
      expect(container.read(sessionProvider).value, SessionStatus.signedOut);
    });
  });

  group('SignupController', () {
    SignupController signup() => container.read(signupProvider.notifier);
    SignupState state() => container.read(signupProvider);

    test('parcours complet : mail → code → identité → connecté', () async {
      await container.read(sessionProvider.future);
      await signup().requestCode('  Lea@ETU.univ-smb.fr ');
      expect(state().step, SignupStep.code);
      expect(state().email, 'lea@etu.univ-smb.fr');
      signup().confirmCode(FakeBackend.code);
      expect(state().step, SignupStep.identity);
      await signup().submit(firstName: ' Léa ', lastName: 'Martin', password: 'motdepasse-solide');
      expect(container.read(sessionProvider).value, SessionStatus.signedIn);
      expect(storage.tokens, isNotNull);
      expect(state().step, SignupStep.email);
    });

    test('domaine refusé : reste sur l’étape mail avec le code d’erreur', () async {
      await signup().requestCode('lea@gmail.com');
      expect(state().step, SignupStep.email);
      expect(state().errorCode, 'email_domain_not_allowed');
      expect(state().busy, isFalse);
    });

    test('code faux : retour à la saisie du code', () async {
      await signup().requestCode('lea@etu.univ-smb.fr');
      signup().confirmCode('000000');
      await signup().submit(firstName: 'Léa', lastName: 'Martin', password: 'motdepasse-solide');
      expect(state().step, SignupStep.code);
      expect(state().errorCode, 'code_invalid');
    });

    test('compte existant : erreur affichée, reste sur l’identité', () async {
      backend.seedAccount('lea@etu.univ-smb.fr');
      await signup().requestCode('lea@etu.univ-smb.fr');
      signup().confirmCode(FakeBackend.code);
      await signup().submit(firstName: 'Léa', lastName: 'Martin', password: 'motdepasse-solide');
      expect(state().step, SignupStep.identity);
      expect(state().errorCode, 'account_exists');
    });

    test('back remonte les étapes et efface l’erreur', () async {
      await signup().requestCode('lea@etu.univ-smb.fr');
      signup().confirmCode('123456');
      signup().back();
      expect(state().step, SignupStep.code);
      signup().back();
      expect(state().step, SignupStep.email);
    });
  });

  group('LoginController', () {
    test('mauvais mot de passe : code d’erreur, pas de session', () async {
      backend.seedAccount('lea@etu.univ-smb.fr');
      await container.read(sessionProvider.future);
      await container
          .read(loginProvider.notifier)
          .login(email: 'lea@etu.univ-smb.fr', password: 'faux');
      expect(container.read(loginProvider).errorCode, 'invalid_credentials');
      expect(container.read(sessionProvider).value, SessionStatus.signedOut);
    });

    test('bon mot de passe : connecté', () async {
      backend.seedAccount('lea@etu.univ-smb.fr');
      await container.read(sessionProvider.future);
      await container
          .read(loginProvider.notifier)
          .login(email: 'LEA@etu.univ-smb.fr', password: 'motdepasse-solide');
      expect(container.read(sessionProvider).value, SessionStatus.signedIn);
    });
  });
}
