import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/theme/um_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/validators.dart';
import 'signup_controller.dart';

/// Inscription en trois étapes ; la navigation retour suit les étapes.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _password = TextEditingController();
  bool _showFieldErrors = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _firstName, _lastName, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  SignupController get _controller => ref.read(signupProvider.notifier);

  void _back(SignupStep step) {
    setState(() => _showFieldErrors = false);
    if (step == SignupStep.email) {
      _controller.reset();
      context.pop();
    } else {
      _controller.back();
    }
  }

  Future<void> _next(SignupStep step) async {
    setState(() => _showFieldErrors = true);
    switch (step) {
      case SignupStep.email:
        if (!AuthValidators.isEmail(_email.text)) return;
        await _controller.requestCode(_email.text);
      case SignupStep.code:
        if (!AuthValidators.isCode(_code.text)) return;
        _controller.confirmCode(_code.text);
      case SignupStep.identity:
        if (!AuthValidators.isName(_firstName.text) ||
            !AuthValidators.isName(_lastName.text) ||
            !AuthValidators.isPassword(_password.text)) {
          return;
        }
        await _controller.submit(
          firstName: _firstName.text,
          lastName: _lastName.text,
          password: _password.text,
        );
    }
    if (mounted) setState(() => _showFieldErrors = false);
  }

  Future<void> _resend(AppLocalizations l10n) async {
    await _controller.resendCode();
    if (!mounted || ref.read(signupProvider).errorCode != null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.signupCodeResent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(signupProvider);
    String? check(bool valid, String message) => _showFieldErrors && !valid ? message : null;

    final (title, intro, action, fields) = switch (state.step) {
      SignupStep.email => (
        l10n.signupEmailTitle,
        l10n.signupEmailBody,
        l10n.signupEmailAction,
        <Widget>[
          UmField(
            label: l10n.emailLabel,
            controller: _email,
            placeholder: l10n.emailPlaceholder,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            error: check(AuthValidators.isEmail(_email.text), l10n.fieldEmailInvalid),
          ),
        ],
      ),
      SignupStep.code => (
        l10n.signupCodeTitle,
        l10n.signupCodeBody(state.email),
        l10n.continueAction,
        <Widget>[
          UmField(
            label: l10n.signupCodeLabel,
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            error: check(AuthValidators.isCode(_code.text), l10n.fieldCodeInvalid),
          ),
        ],
      ),
      SignupStep.identity => (
        l10n.signupIdentityTitle,
        l10n.signupIdentityBody,
        l10n.signupIdentityAction,
        <Widget>[
          UmField(
            label: l10n.firstNameLabel,
            controller: _firstName,
            autofillHints: const [AutofillHints.givenName],
            error: check(AuthValidators.isName(_firstName.text), l10n.fieldRequired),
          ),
          const SizedBox(height: UmSpace.s4),
          UmField(
            label: l10n.lastNameLabel,
            controller: _lastName,
            autofillHints: const [AutofillHints.familyName],
            error: check(AuthValidators.isName(_lastName.text), l10n.fieldRequired),
          ),
          const SizedBox(height: UmSpace.s4),
          UmField(
            label: l10n.passwordLabel,
            controller: _password,
            obscureText: true,
            help: l10n.passwordHelp,
            autofillHints: const [AutofillHints.newPassword],
            error: check(AuthValidators.isPassword(_password.text), l10n.fieldPasswordTooShort),
          ),
        ],
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(state.step);
      },
      child: UmPage(
        appBar: AppBar(leading: BackButton(onPressed: () => _back(state.step))),
        overline: l10n.onboardingProgress(state.step.index + 1, SignupStep.values.length),
        title: title,
        intro: intro,
        footer: [
          UmButton(
            label: action,
            expand: true,
            loading: state.busy,
            onPressed: () => _next(state.step),
          ),
          if (state.step == SignupStep.code) ...[
            UmButton(
              label: l10n.signupCodeResend,
              variant: UmButtonVariant.ghost,
              expand: true,
              onPressed: state.busy ? null : () => _resend(l10n),
            ),
            UmButton(
              label: l10n.signupChangeEmail,
              variant: UmButtonVariant.ghost,
              expand: true,
              onPressed: () => _back(state.step),
            ),
          ],
        ],
        children: [
          ...fields,
          if (state.errorCode != null) ...[
            const SizedBox(height: UmSpace.s4),
            UmErrorText(apiErrorMessage(l10n, state.errorCode)),
          ],
        ],
      ),
    );
  }
}
