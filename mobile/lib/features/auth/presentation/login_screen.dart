import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/validators.dart';
import 'signup_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showFieldErrors = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _showFieldErrors = true);
    if (!AuthValidators.isEmail(_email.text) || _password.text.isEmpty) return;
    await ref.read(loginProvider.notifier).login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginProvider);
    final emailError = _showFieldErrors && !AuthValidators.isEmail(_email.text)
        ? l10n.fieldEmailInvalid
        : null;
    final passwordError = _showFieldErrors && _password.text.isEmpty ? l10n.fieldRequired : null;

    return UmPage(
      appBar: AppBar(),
      title: l10n.loginTitle,
      footer: [
        UmButton(label: l10n.loginAction, expand: true, loading: state.busy, onPressed: _submit),
        UmButton(
          label: l10n.loginNoAccount,
          variant: UmButtonVariant.ghost,
          expand: true,
          onPressed: () => context.pushReplacement(AppRoutes.signup),
        ),
      ],
      children: [
        UmField(
          label: l10n.emailLabel,
          controller: _email,
          placeholder: l10n.emailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          error: emailError,
        ),
        const SizedBox(height: UmSpace.s4),
        UmField(
          label: l10n.passwordLabel,
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          error: passwordError,
        ),
        if (state.errorCode != null) ...[
          const SizedBox(height: UmSpace.s4),
          UmErrorText(apiErrorMessage(l10n, state.errorCode)),
        ],
      ],
    );
  }
}
