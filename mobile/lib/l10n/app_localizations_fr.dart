// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Uni-Moov';

  @override
  String get logoLabel => 'Logo Uni-Moov';

  @override
  String get retry => 'Réessayer';

  @override
  String get fieldErrorPrefix => 'Erreur';

  @override
  String get fieldShowPassword => 'Afficher le mot de passe';

  @override
  String get fieldHidePassword => 'Masquer le mot de passe';

  @override
  String rideFrom(String place) {
    return 'Départ : $place';
  }

  @override
  String rideTo(String place) {
    return 'Arrivée : $place';
  }

  @override
  String rideMeta(String time, String driver) {
    return '$time · avec $driver';
  }

  @override
  String rideSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places libres',
      one: '1 place libre',
      zero: 'Complet',
    );
    return '$_temp0';
  }

  @override
  String ridePriceLabel(String price) {
    return 'Prix estimé : $price';
  }

  @override
  String get rideStatusProposed => 'Proposé';

  @override
  String get rideStatusConfirmed => 'Confirmé';

  @override
  String get rideStatusCancelled => 'Annulé';

  @override
  String get welcomeTitle => 'Ton emploi du temps organise aussi tes trajets.';

  @override
  String get welcomeSubtitle => 'Covoiturage domicile-campus pour les étudiants d\'Annecy';

  @override
  String get welcomeNote => 'Inscris-toi en deux minutes !';

  @override
  String get welcomeBenefitSchedule => 'Trajets calés sur tes cours';

  @override
  String get welcomeBenefitPrice => 'Frais partagés au juste prix';

  @override
  String get welcomeBenefitConfirm => 'Confirmé à deux, toujours';

  @override
  String get welcomeSignup => 'Créer mon compte';

  @override
  String get welcomeLogin => 'J\'ai déjà un compte';

  @override
  String get back => 'Retour';

  @override
  String get loading => 'Chargement…';

  @override
  String get continueAction => 'Continuer';

  @override
  String get skipForNow => 'Passer pour l\'instant';

  @override
  String get save => 'Enregistrer';

  @override
  String get edit => 'Modifier';

  @override
  String get errorGeneric => 'Une erreur est survenue. Réessaie.';

  @override
  String get errorNetwork => 'Connexion impossible pour l\'instant. Vérifie ton réseau.';

  @override
  String get errorRateLimited => 'Trop de tentatives. Réessaie dans quelques minutes.';

  @override
  String get errorValidation => 'Vérifie les informations saisies.';

  @override
  String get errorSessionExpired => 'Ta session a expiré. Connecte-toi à nouveau.';

  @override
  String get errorEmailDomain => 'Utilise ton adresse mail universitaire (univ-smb.fr).';

  @override
  String get errorCodeCooldown => 'Attends une minute avant de redemander un code.';

  @override
  String get errorCodeInvalid => 'Code incorrect ou expiré. Vérifie-le ou demande un nouveau code.';

  @override
  String get errorAccountExists => 'Tu as déjà un compte avec cette adresse. Connecte-toi.';

  @override
  String get errorInvalidCredentials => 'Mail ou mot de passe incorrect.';

  @override
  String get errorAddressNotFound => 'Adresse introuvable. Ajoute la ville ou le code postal.';

  @override
  String get errorGeocodingUnavailable =>
      'Recherche d\'adresse indisponible. Réessaie plus tard ou passe cette étape.';

  @override
  String get errorVehicleRequired => 'Ajoute un véhicule pour conduire.';

  @override
  String get errorInvalidPause =>
      'Vérifie les dates : la fin suit le début et la pause dure un an au plus.';

  @override
  String get errorTooManyPauses =>
      'Tu as déjà programmé beaucoup de pauses. Supprimes-en une d\'abord.';

  @override
  String get fieldEmailInvalid => 'Saisis une adresse mail valide.';

  @override
  String get fieldCodeInvalid => 'Le code contient 6 chiffres.';

  @override
  String get fieldPasswordTooShort => '8 caractères minimum.';

  @override
  String get fieldRequired => 'Ce champ est obligatoire.';

  @override
  String fieldNumberInvalid(num min, num max) {
    return 'Saisis un nombre entre $min et $max.';
  }

  @override
  String get emailLabel => 'Mail universitaire';

  @override
  String get emailPlaceholder => 'prenom.nom@etu.univ-smb.fr';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordHelp => '8 caractères minimum.';

  @override
  String get firstNameLabel => 'Prénom';

  @override
  String get lastNameLabel => 'Nom';

  @override
  String get signupEmailTitle => 'Crée ton compte';

  @override
  String get signupEmailBody =>
      'Utilise ton adresse mail universitaire : on t\'envoie un code pour la vérifier.';

  @override
  String get signupEmailAction => 'Recevoir mon code';

  @override
  String get signupCodeTitle => 'Vérifie ta boîte mail';

  @override
  String signupCodeBody(String email) {
    return 'Saisis le code à 6 chiffres envoyé à $email. Il est valable 10 minutes.';
  }

  @override
  String get signupCodeLabel => 'Code de confirmation';

  @override
  String get signupCodeResend => 'Renvoyer le code';

  @override
  String get signupCodeResent => 'Nouveau code envoyé.';

  @override
  String get signupChangeEmail => 'Changer d\'adresse';

  @override
  String get signupIdentityTitle => 'Présente-toi';

  @override
  String get signupIdentityBody =>
      'Les autres étudiants voient ton prénom. Ton nom n\'apparaît qu\'après un trajet confirmé à deux.';

  @override
  String get signupIdentityAction => 'Créer mon compte';

  @override
  String get loginTitle => 'Content de te revoir';

  @override
  String get loginAction => 'Me connecter';

  @override
  String get loginNoAccount => 'Créer un compte';

  @override
  String get splashError => 'Impossible de charger ton profil.';

  @override
  String get signOut => 'Me déconnecter';

  @override
  String onboardingProgress(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get addressTitle => 'Où habites-tu ?';

  @override
  String get addressBody =>
      'Ton adresse sert à trouver des trajets près de chez toi. Avant un trajet confirmé à deux, les autres ne voient qu\'un secteur approximatif.';

  @override
  String get addressLabel => 'Adresse';

  @override
  String get addressPlaceholder => '12 rue de la Paix, Annecy';

  @override
  String addressFound(String address) {
    return 'Adresse enregistrée : $address';
  }

  @override
  String get vehicleTitle => 'As-tu une voiture ?';

  @override
  String get vehicleBody =>
      'Avec une voiture, tu peux conduire et partager les frais avec tes passagers.';

  @override
  String get vehicleYes => 'Oui, j\'ai une voiture';

  @override
  String get vehicleNo => 'Non, pas de voiture';

  @override
  String get vehicleConsumptionLabel => 'Consommation (L/100 km)';

  @override
  String get vehicleConsumptionHelp => 'Sert à calculer le partage des frais.';

  @override
  String get vehicleSeatsLabel => 'Places passagers';

  @override
  String get vehicleDetourLabel => 'Détour maximal (minutes)';

  @override
  String get vehicleDetourHelp => 'On ne te propose que des passagers sous ce détour.';

  @override
  String get roleTitle => 'Quel rôle préfères-tu ?';

  @override
  String get roleBody => 'Tu pourras le changer quand tu veux depuis ton profil.';

  @override
  String get roleAuto => 'Automatique';

  @override
  String get roleAutoHelp =>
      'Uni-Moov te propose conducteur ou passager selon les besoins de la semaine.';

  @override
  String get roleDriver => 'Toujours conducteur';

  @override
  String get rolePassenger => 'Toujours passager';

  @override
  String get roleNoVehicle =>
      'Sans voiture, tu voyages en passager. Tu peux ajouter un véhicule plus tard dans ton profil.';

  @override
  String get calendarTitle => 'Ton emploi du temps';

  @override
  String get calendarBody =>
      'Bientôt, Uni-Moov lira ton emploi du temps pour te proposer tes trajets de la semaine. Tu le connecteras depuis ton profil.';

  @override
  String get calendarAction => 'Terminer';

  @override
  String homeGreeting(String firstName) {
    return 'Salut $firstName';
  }

  @override
  String get homeProfileTooltip => 'Mon profil';

  @override
  String get discoveryTitle => 'Mode découverte';

  @override
  String get discoveryBody => 'Ajoute ton adresse pour recevoir des propositions de trajets.';

  @override
  String get discoveryAction => 'Compléter mon profil';

  @override
  String get pausedToday => 'En pause aujourd\'hui';

  @override
  String get pauseAction => 'Mettre en pause';

  @override
  String get pauseManage => 'Gérer mes pauses';

  @override
  String get weekTitle => 'Ta semaine';

  @override
  String get weekEmpty =>
      'Tes propositions de trajets arriveront ici une fois ton emploi du temps connecté.';

  @override
  String get profileTitle => 'Mon profil';

  @override
  String get profileIdentity => 'Identité';

  @override
  String get profileAddress => 'Adresse';

  @override
  String get profileNoAddress => 'Aucune adresse enregistrée.';

  @override
  String get profileVehicle => 'Véhicule';

  @override
  String get profileNoVehicle => 'Pas de véhicule.';

  @override
  String profileVehicleSummary(String consumption, int seats, int detour) {
    return '$consumption L/100 km · $seats places · détour $detour min';
  }

  @override
  String get profileRemoveVehicle => 'Retirer le véhicule';

  @override
  String get profileRole => 'Rôle';

  @override
  String get profilePauses => 'Pauses';

  @override
  String get profileNoPauses => 'Aucune pause programmée.';

  @override
  String pauseRange(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String pauseAlternating(int weeks) {
    return 'une semaine sur $weeks';
  }

  @override
  String pauseDelete(String start) {
    return 'Supprimer la pause du $start';
  }

  @override
  String get pauseSheetTitle => 'Mettre en pause';

  @override
  String get pauseSheetBody =>
      'Pendant une pause, tu ne reçois pas de propositions. Ton score de fiabilité n\'est pas touché.';

  @override
  String get pauseChooseDates => 'Choisir les dates';

  @override
  String get pauseAlternatingToggle => 'Une semaine sur deux (alternance)';

  @override
  String get pauseSave => 'Enregistrer la pause';
}
