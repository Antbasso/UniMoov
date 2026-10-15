/// Contrôles de saisie côté app, pour un retour immédiat. Le serveur reste l'arbitre
/// (domaine universitaire, code, règles du mot de passe).
abstract final class AuthValidators {
  static const passwordMinLength = 8;
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _code = RegExp(r'^\d{6}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());
  static bool isCode(String value) => _code.hasMatch(value.trim());
  static bool isPassword(String value) => value.length >= passwordMinLength;
  static bool isName(String value) => value.trim().isNotEmpty;
}
