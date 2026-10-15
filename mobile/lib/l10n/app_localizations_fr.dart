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
    return 'Saisis le code à 6 chiffres envoyé à $email. Il est valable 10 minutes. Pense à regarder dans tes spams.';
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
  String get loginTitle => 'Te revoilà';

  @override
  String get loginAction => 'Me connecter';

  @override
  String get loginNoAccount => 'Créer mon compte';

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
  String get vehicleBody => 'Avec une voiture, tu peux conduire et partager les frais du trajet.';

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
  String get vehicleDetourHelp => 'Uni-Moov ne te propose que des détours plus courts.';

  @override
  String get roleTitle => 'Quel rôle préfères-tu ?';

  @override
  String get roleBody => 'Tu pourras le changer quand tu veux depuis ton profil.';

  @override
  String get roleAuto => 'Automatique';

  @override
  String get roleAutoHelp =>
      'Chaque semaine, Uni-Moov choisit si tu conduis ou non, selon les besoins.';

  @override
  String get roleDriver => 'Toujours au volant';

  @override
  String get rolePassenger => 'Toujours côté passager';

  @override
  String get roleNoVehicle =>
      'Sans voiture, tu voyages côté passager. Tu peux ajouter un véhicule plus tard dans ton profil.';

  @override
  String get calendarTitle => 'Ton emploi du temps';

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

  @override
  String get rideStatusWaiting => 'En attente';

  @override
  String get campusName => 'Campus d\'Annecy';

  @override
  String get nearYourHome => 'Près de chez toi';

  @override
  String get yourHome => 'Chez toi';

  @override
  String get calendarBody =>
      'Uni-Moov lit ton emploi du temps pour te proposer tes trajets de la semaine. Choisis comment le partager.';

  @override
  String get calendarChooseIcs => 'Coller mon lien d\'agenda (ICS)';

  @override
  String get calendarChooseManual => 'Saisir mes horaires';

  @override
  String get icsTitle => 'Ton lien d\'agenda';

  @override
  String get icsBody =>
      'Copie le lien d\'abonnement (ICS) de ton emploi du temps, par exemple depuis ADE, puis colle-le ici.';

  @override
  String get icsLabel => 'Lien ICS';

  @override
  String get icsPlaceholder => 'https://…';

  @override
  String get icsConsent =>
      'J\'accepte qu\'Uni-Moov lise cet agenda pour n\'en garder que l\'heure de début et de fin de chaque journée. Les intitulés de cours ne sont pas conservés. Je peux le déconnecter à tout moment.';

  @override
  String get icsConsentRequired => 'Coche la case pour autoriser la lecture de ton agenda.';

  @override
  String get icsConnect => 'Connecter mon agenda';

  @override
  String get manualTitle => 'Tes horaires de la semaine';

  @override
  String get manualBody =>
      'Indique l\'heure de ton premier cours et la fin de ton dernier, pour chaque jour.';

  @override
  String get manualSave => 'Enregistrer mes horaires';

  @override
  String get manualStart => 'Début';

  @override
  String get manualEnd => 'Fin';

  @override
  String get manualDayOff => 'Pas de cours';

  @override
  String get manualInvalid => 'La fin de journée doit suivre son début.';

  @override
  String manualTimeLabel(String day, String which, String time) {
    return '$day, $which : $time';
  }

  @override
  String get weekday1 => 'Lundi';

  @override
  String get weekday2 => 'Mardi';

  @override
  String get weekday3 => 'Mercredi';

  @override
  String get weekday4 => 'Jeudi';

  @override
  String get weekday5 => 'Vendredi';

  @override
  String get weekday6 => 'Samedi';

  @override
  String get weekday7 => 'Dimanche';

  @override
  String get errorCalendarUrl => 'Ce lien n\'est pas valide. Il doit commencer par https://.';

  @override
  String get errorCalendarUnreachable =>
      'Impossible de lire ton agenda. Vérifie le lien ou réessaie plus tard.';

  @override
  String get errorCalendarInvalid =>
      'Ce lien ne renvoie pas un agenda. Copie le lien d\'abonnement (ICS).';

  @override
  String get errorDuplicateWeekday => 'Un même jour est saisi deux fois.';

  @override
  String get errorProposalExpired => 'Cette proposition est passée.';

  @override
  String get errorProposalCancelled => 'Cette proposition a été annulée.';

  @override
  String get errorRideUnavailable => 'Cette voiture ne peut plus te prendre. Choisis-en une autre.';

  @override
  String get errorAlreadyCommitted => 'Tu as déjà un trajet sur ce créneau.';

  @override
  String get errorAlreadyDriving => 'Tu conduis déjà sur ce créneau.';

  @override
  String get errorAlreadyAnswered => 'Tu as déjà répondu à cette proposition.';

  @override
  String get errorSearchQuota => 'Tu as atteint le nombre de recherches du jour. Réessaie demain.';

  @override
  String get errorProfileIncomplete => 'Ajoute ton adresse pour trouver un trajet.';

  @override
  String get errorTimeRequired => 'Indique une heure pour ce jour.';

  @override
  String get weekThis => 'Cette semaine';

  @override
  String get weekNext => 'La suivante';

  @override
  String get weekEmpty =>
      'Pas encore de proposition cette semaine. Vérifie ton emploi du temps ou cherche un trajet.';

  @override
  String get weekEmptyNoSchedule => 'Ajoute ton emploi du temps pour recevoir tes propositions.';

  @override
  String get addSchedule => 'Ajouter mon emploi du temps';

  @override
  String get searchAction => 'Chercher un trajet';

  @override
  String get directionTo => 'Aller';

  @override
  String get directionFrom => 'Retour';

  @override
  String rideMetaDriver(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passagers',
      one: '1 passager',
      zero: 'aucun passager pour l\'instant',
    );
    return '$time · tu conduis · $_temp0';
  }

  @override
  String get see => 'Voir';

  @override
  String proposalTitleTo(String day) {
    return 'Aller du $day';
  }

  @override
  String proposalTitleFrom(String day) {
    return 'Retour du $day';
  }

  @override
  String proposalTime(String time) {
    return 'Horaire : $time';
  }

  @override
  String get proposalDriverIntro => 'Tu montes avec';

  @override
  String get proposalPassengersIntro => 'Tes passagers';

  @override
  String get proposalNoPassengers =>
      'Personne pour l\'instant. Tu recevras une notification si quelqu\'un est proposé.';

  @override
  String personDetails(String score, int minutes) {
    return 'Fiabilité $score sur 5 · détour $minutes min · secteur approximatif';
  }

  @override
  String get privacyNote =>
      'Nom et adresse exacte s\'affichent seulement une fois le trajet confirmé à deux.';

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String get seeOthers => 'Voir d\'autres voitures';

  @override
  String get proposalConfirmed => 'Trajet confirmé';

  @override
  String get proposalWaiting => 'Tu as accepté. On attend la réponse de l\'autre.';

  @override
  String get proposalDeclined => 'Proposition refusée.';

  @override
  String get alternativesTitle => 'Autres voitures';

  @override
  String get alternativesEmpty => 'Aucune autre voiture compatible pour ce créneau.';

  @override
  String get choose => 'Choisir';

  @override
  String get joined => 'C\'est noté : tu as choisi cette voiture.';

  @override
  String get searchTitle => 'Chercher un trajet';

  @override
  String get searchDayLabel => 'Jour';

  @override
  String get searchTimeOptional => 'Heure (facultatif)';

  @override
  String get searchNoTime => 'Selon mon emploi du temps';

  @override
  String get searchEmpty => 'Aucune voiture trouvée pour ce créneau.';

  @override
  String get searchHint => 'Choisis un jour et un sens, puis lance la recherche.';

  @override
  String seatsLeftLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String get profileSchedule => 'Emploi du temps';

  @override
  String scheduleConnected(String date) {
    return 'Agenda connecté, mis à jour le $date.';
  }

  @override
  String get scheduleSyncError => 'La dernière mise à jour a échoué. Vérifie ton lien.';

  @override
  String scheduleManualSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return 'Horaires saisis pour $_temp0.';
  }

  @override
  String get scheduleNone => 'Aucun emploi du temps.';

  @override
  String get scheduleSync => 'Mettre à jour';

  @override
  String get scheduleDisconnect => 'Déconnecter l\'agenda';

  @override
  String get scheduleSynced => 'Emploi du temps mis à jour.';
}
