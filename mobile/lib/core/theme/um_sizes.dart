/// Dimensions des composants fixées par docs/design-system (components/*.md, components.css)
/// et absentes de tokens.json. Les widgets n'écrivent jamais ces valeurs en dur.
abstract final class UmSize {
  /// Zone tactile minimale (boutons, champs).
  static const double tapTarget = 48;

  /// Anneau de focus : 3 px pleins, décalé de 2 px.
  static const double focusRing = 3;
  static const double focusOffset = 2;

  /// Bordure des champs et des boutons secondaires.
  static const double controlBorder = 2;

  /// Icônes : puce (16), interface (24), bénéfice (48) ; trait des icônes dessinées.
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 48;
  static const double iconStroke = 2.5;

  /// Largeurs maximales conseillées.
  static const double fieldMaxWidth = 360;
  static const double rideCardMaxWidth = 420;

  /// Bord coloré d'une carte de trajet (teinte de l'état).
  static const double rideAccent = 4;

  /// Pastille du rôle (voiture ou siège) sur une carte de trajet.
  static const double roleBadge = 32;

  /// Photo de profil : liste, puis en-tête de profil.
  static const double avatar = 40;
  static const double avatarLg = 64;
  static const double avatarXl = 96;

  /// Repères de trajet de la carte : pastille pleine et anneau d'arrivée.
  static const double routeDot = 12;
  static const double routeRing = 3;

  /// Carte du trajet : hauteur, repères d'arrêt, épaisseur du tracé, zoom maximal au cadrage.
  static const double mapHeight = 300;
  static const double mapMarker = 36;
  static const double routeStroke = 5;
  static const double mapMaxZoom = 16;

  /// Mini-carte du secteur d'une personne, dans sa fiche.
  static const double sectorMiniMap = 160;

  /// Pastille numérotée d'un arrêt dans la liste.
  static const double stopBadge = 32;

  /// Logo complet : largeur affichée (minimum 120 px, logo.md).
  static const double logoWidth = 160;

  /// Logo de l'écran d'accueil (avant connexion), au plus.
  static const double logoHero = 220;

  /// Inclinaison du sticker manuscrit, en degrés.
  static const double noteAngleDegrees = -4;

  /// Opacité d'un contrôle désactivé (reste lisible).
  static const double disabledOpacity = 0.45;
}

abstract final class UmMotion {
  /// Transitions de fond et de bordure.
  static const fast = Duration(milliseconds: 150);
}
