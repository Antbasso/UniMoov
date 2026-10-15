import '../../l10n/app_localizations.dart';

/// Traduit un code d'erreur de l'API (docs/api.md) en message pour l'utilisateur.
String apiErrorMessage(AppLocalizations l10n, String? code) => switch (code) {
  'network_error' => l10n.errorNetwork,
  'rate_limited' => l10n.errorRateLimited,
  'validation_error' || 'bad_request' => l10n.errorValidation,
  'unauthorized' || 'invalid_refresh_token' => l10n.errorSessionExpired,
  'email_domain_not_allowed' => l10n.errorEmailDomain,
  'code_cooldown' => l10n.errorCodeCooldown,
  'code_invalid' => l10n.errorCodeInvalid,
  'account_exists' => l10n.errorAccountExists,
  'invalid_credentials' => l10n.errorInvalidCredentials,
  'address_not_found' => l10n.errorAddressNotFound,
  'geocoding_unavailable' => l10n.errorGeocodingUnavailable,
  'vehicle_required' => l10n.errorVehicleRequired,
  'invalid_pause' => l10n.errorInvalidPause,
  'too_many_pauses' => l10n.errorTooManyPauses,
  _ => l10n.errorGeneric,
};
