import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_api.dart';
import 'session_controller.dart';

enum SignupStep { email, code, identity }

class SignupState {
  const SignupState({
    this.step = SignupStep.email,
    this.email = '',
    this.code = '',
    this.busy = false,
    this.errorCode,
  });

  final SignupStep step;
  final String email;
  final String code;
  final bool busy;

  /// Code d'erreur de l'API (ou `invalid_input`), traduit par l'écran.
  final String? errorCode;

  SignupState copyWith({
    SignupStep? step,
    String? email,
    String? code,
    bool? busy,
    String? errorCode,
    bool clearError = false,
  }) => SignupState(
    step: step ?? this.step,
    email: email ?? this.email,
    code: code ?? this.code,
    busy: busy ?? this.busy,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
  );
}

/// Inscription en trois temps : mail universitaire → code reçu → identité et mot de passe.
/// Le code n'est vérifié par le serveur qu'à la dernière étape (création du compte).
class SignupController extends Notifier<SignupState> {
  @override
  SignupState build() => const SignupState();

  AuthApi get _api => ref.read(authApiProvider);

  Future<void> requestCode(String email) async {
    final normalized = email.trim().toLowerCase();
    state = state.copyWith(busy: true, email: normalized, clearError: true);
    try {
      await _api.requestCode(normalized);
      state = state.copyWith(busy: false, step: SignupStep.code);
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, errorCode: error.code);
    }
  }

  Future<void> resendCode() => requestCode(state.email);

  void confirmCode(String code) {
    state = state.copyWith(code: code.trim(), step: SignupStep.identity, clearError: true);
  }

  Future<void> submit({
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final tokens = await _api.verify(
        universityEmail: state.email,
        code: state.code,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        password: password,
      );
      await ref.read(sessionProvider.notifier).signIn(tokens);
      state = const SignupState();
    } on ApiException catch (error) {
      // Code refusé : retour à la saisie du code, le reste est conservé.
      state = state.copyWith(
        busy: false,
        errorCode: error.code,
        step: error.code == 'code_invalid' ? SignupStep.code : state.step,
      );
    }
  }

  void back() {
    final previous = switch (state.step) {
      SignupStep.identity => SignupStep.code,
      SignupStep.code || SignupStep.email => SignupStep.email,
    };
    state = state.copyWith(step: previous, clearError: true);
  }

  void reset() => state = const SignupState();
}

final signupProvider = NotifierProvider<SignupController, SignupState>(SignupController.new);

class LoginState {
  const LoginState({this.busy = false, this.errorCode});

  final bool busy;
  final String? errorCode;
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> login({required String email, required String password}) async {
    state = const LoginState(busy: true);
    try {
      final tokens = await ref
          .read(authApiProvider)
          .login(universityEmail: email.trim().toLowerCase(), password: password);
      await ref.read(sessionProvider.notifier).signIn(tokens);
      state = const LoginState();
    } on ApiException catch (error) {
      state = LoginState(errorCode: error.code);
    }
  }
}

final loginProvider = NotifierProvider<LoginController, LoginState>(LoginController.new);
