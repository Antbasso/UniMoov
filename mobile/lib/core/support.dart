/// Adresse de l'équipe (droits RGPD, solde à récupérer) ; même valeur que le réglage
/// serveur `support.email`.
const supportEmail = 'unimoov.support@gmail.com';

Uri supportMailto({String? subject}) => Uri(
  scheme: 'mailto',
  path: supportEmail,
  query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
);
