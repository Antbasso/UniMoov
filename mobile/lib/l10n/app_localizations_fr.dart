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
  String ridePriceLabel(String price) {
    return 'Prix estimé : $price';
  }

  @override
  String get rideStatusProposed => 'À confirmer';

  @override
  String get rideStatusConfirmed => 'Confirmé';

  @override
  String get rideStatusCancelled => 'Annulé';

  @override
  String get welcomeTitle => 'Ton emploi du temps organise aussi tes trajets.';

  @override
  String get welcomeSubtitle => 'Covoiturage domicile-campus pour les étudiants d\'Annecy';

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
  String get demoTry => 'Essayer la démo';

  @override
  String get demoSheetTitle => 'Essayer Uni-Moov sans compte';

  @override
  String get demoSheetBody =>
      'Des données fictives autour du campus d\'Annecy, sans réseau : rien n\'est envoyé ni payé.';

  @override
  String get demoReady => 'Compte prêt : Camille';

  @override
  String get demoReadyHelp =>
      'Une semaine remplie : trajet en cours, trajet à conduire, propositions, portefeuille et messages.';

  @override
  String get demoSignup => 'Parcours d\'inscription';

  @override
  String get demoSignupHelp =>
      'De l\'adresse mail à la semaine type, avec n\'importe quelle adresse en univ-smb.fr.';

  @override
  String get demoBanner => 'DÉMO';

  @override
  String demoCodeHint(String code) {
    return 'Démo : le code est $code.';
  }

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
  String get addressPickHelp => 'Commence à taper, puis choisis ton adresse dans la liste.';

  @override
  String get addressPickRequired => 'Choisis une adresse dans la liste proposée.';

  @override
  String get addressNoSuggestion => 'Aucune adresse trouvée : vérifie le numéro et la commune.';

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
  String get navMessages => 'Messages';

  @override
  String get navHome => 'Accueil';

  @override
  String get navProfile => 'Profil';

  @override
  String get badgeDriver => 'Tu conduis';

  @override
  String get badgePassenger => 'Passager';

  @override
  String liveBannerTitle(String role, String time) {
    return 'Trajet en cours · $role · $time';
  }

  @override
  String get liveBannerAction => 'Voir';

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
  String get weekTitle => 'Ta semaine';

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
  String pauseOn(String date) {
    return 'Le $date';
  }

  @override
  String pauseUntil(String date) {
    return 'jusqu\'au $date';
  }

  @override
  String pauseEveryWeekdays(String days) {
    return 'Tous les $days';
  }

  @override
  String pauseEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'toutes les $count semaines',
      one: 'chaque semaine',
    );
    return '$_temp0';
  }

  @override
  String pauseEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tous les $count mois',
      one: 'chaque mois',
    );
    return '$_temp0';
  }

  @override
  String get and => 'et';

  @override
  String pauseDelete(String start) {
    return 'Supprimer la pause du $start';
  }

  @override
  String get pauseSheetTitle => 'Mettre en pause';

  @override
  String get pauseSheetBody => 'Pas de propositions pendant la pause. Ton score n\'est pas touché.';

  @override
  String get pauseChooseDates => 'Choisir les dates';

  @override
  String get pauseModeDates => 'Dates';

  @override
  String get pauseModeDays => 'Jours';

  @override
  String get pauseModeRepeat => 'Répéter';

  @override
  String get pauseModeLabel => 'Type de pause';

  @override
  String get pauseDatesLabel => 'Période de pause';

  @override
  String get pauseDaysLabel => 'Chaque semaine, les jours :';

  @override
  String get pauseFirstLabel => 'Première pause';

  @override
  String get pauseFrequencyLabel => 'Fréquence';

  @override
  String get pauseUntilLabel => 'Jusqu\'au';

  @override
  String get pauseChooseUntil => 'Choisir la date de fin';

  @override
  String get pauseChooseFirst => 'Choisir la première pause';

  @override
  String get pauseTooLongForPeriod => 'La pause est plus longue que sa fréquence : raccourcis-la.';

  @override
  String get pauseSave => 'Enregistrer la pause';

  @override
  String get rideStatusWaiting => 'En attente';

  @override
  String get campusName => 'Campus d\'Annecy';

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
  String get manualTitle => 'Tes horaires de la semaine';

  @override
  String get manualBody =>
      'Indique l\'heure de ton premier cours et la fin de ton dernier, pour chaque jour.';

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
  String proposalTitleTo(String day) {
    return 'Aller du $day';
  }

  @override
  String proposalTitleFrom(String day) {
    return 'Retour du $day';
  }

  @override
  String get proposalNoPassengers =>
      'Personne pour l\'instant. Tu recevras une notification si quelqu\'un est proposé.';

  @override
  String personDetails(String score, int minutes) {
    return 'Fiabilité $score sur 5 · détour $minutes min';
  }

  @override
  String get privacyNote =>
      'Nom et adresse sont partagés seulement quand vous avez accepté tous les deux.';

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String get seeOthers => 'Voir d\'autres voitures';

  @override
  String get proposalConfirmed => 'Trajet confirmé';

  @override
  String get alternativesTitle => 'Autres voitures';

  @override
  String get alternativesEmpty => 'Aucune autre voiture compatible pour ce créneau.';

  @override
  String get choose => 'Choisir';

  @override
  String get joined => 'Demande envoyée : le conducteur doit l\'accepter.';

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

  @override
  String rideMapLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrêts',
      one: '1 arrêt',
    );
    return 'Carte du trajet avec $_temp0';
  }

  @override
  String get rideRouteEstimated =>
      'Tracé approximatif : le calcul d\'itinéraire n\'était pas disponible.';

  @override
  String rideStopAround(String time) {
    return 'Vers $time';
  }

  @override
  String rideStopSemantic(int order, String name, String place, String time) {
    return 'Arrêt $order : $name, $place, vers $time';
  }

  @override
  String get rideYou => 'Toi';

  @override
  String get rideMeetingPoint => 'Point de rendez-vous';

  @override
  String ridePriceYouPay(String price) {
    return 'Tu paies $price';
  }

  @override
  String ridePriceYouReceive(String price) {
    return 'Tu reçois $price';
  }

  @override
  String get ridePriceUnknown =>
      'Prix indisponible : le véhicule du conducteur n\'est plus renseigné.';

  @override
  String get rideAddPassengers => 'Ajouter des passagers';

  @override
  String get rideChooseMeetingPoint => 'Fixer un rendez-vous';

  @override
  String get rideChangeMeetingPoint => 'Modifier le rendez-vous';

  @override
  String get meetingPointTitle => 'Point de rendez-vous';

  @override
  String get meetingPointIntro =>
      'Touche la carte pour placer le point où le conducteur te prendra. Il remplace ton adresse et doit rester près de chez toi.';

  @override
  String get meetingPointMapLabel => 'Carte : touche pour placer le point de rendez-vous';

  @override
  String get meetingPointLabel => 'Nom du point';

  @override
  String get meetingPointHint => 'Ex. arrêt de bus Mairie';

  @override
  String get meetingPointSave => 'Enregistrer ce point';

  @override
  String get meetingPointReset => 'Revenir à mon adresse';

  @override
  String get meetingPointSaved => 'Point de rendez-vous enregistré.';

  @override
  String get meetingPointResetDone => 'Le conducteur passera à ton adresse.';

  @override
  String get suggestionsTitle => 'Ajouter des passagers';

  @override
  String get suggestionsIntro =>
      'Ces étudiants n\'ont pas encore de trajet à cette heure-là. Chaque place prise fait baisser le prix pour tout le monde.';

  @override
  String suggestionsCurrentPrice(String price) {
    return 'Aujourd\'hui, chaque passager paie $price.';
  }

  @override
  String get suggestionWithin => 'Dans ton détour';

  @override
  String get suggestionBeyond => 'Au-delà de ton détour max';

  @override
  String suggestionPrice(String price) {
    return 'Avec cette personne : $price par passager';
  }

  @override
  String get suggestionInvite => 'Proposer une place';

  @override
  String suggestionInvited(String name) {
    return 'Proposition envoyée à $name.';
  }

  @override
  String get suggestionsEmpty => 'Personne d\'autre ne cherche de trajet à cette heure-là.';

  @override
  String get suggestionsFull => 'Ta voiture est complète.';

  @override
  String get errorForbidden => 'Tu n\'as pas accès à ce trajet.';

  @override
  String get errorRideNotConfirmed => 'Ce trajet n\'est pas encore confirmé.';

  @override
  String get errorMeetingPointTooFar => 'Choisis un point plus proche de chez toi.';

  @override
  String get errorRideLocked => 'Ce trajet ne peut plus être modifié.';

  @override
  String get errorSuggestionUnavailable => 'Cette personne n\'est plus disponible.';

  @override
  String get errorAcceptFirst => 'Accepte d\'abord ce trajet.';

  @override
  String get ridePricePayLabel => 'Tu paies';

  @override
  String get ridePriceReceiveLabel => 'Tu reçois';

  @override
  String suggestionPriceCompared(String price, String current) {
    return 'Avec cette personne : $price par passager au lieu de $current';
  }

  @override
  String get rideStopApproximate => 'Position approximative';

  @override
  String get rideInProgress => 'Trajet en cours';

  @override
  String get rideCompleted => 'Trajet terminé';

  @override
  String liveDriverEta(String time) {
    return 'Le conducteur arrive vers $time';
  }

  @override
  String liveLastKnown(String time) {
    return 'Dernière position connue à $time';
  }

  @override
  String get liveWaiting => 'En attente de la position du conducteur.';

  @override
  String get liveReconnecting => 'Connexion au suivi en direct…';

  @override
  String get liveEnded => 'Le suivi en direct est terminé.';

  @override
  String get presenceValidated => 'Présence validée';

  @override
  String get presenceOnBoard => 'Présence validée : ta part est prélevée à la fin du trajet';

  @override
  String get tripArrived =>
      'Arrivée à destination : ta part est prélevée à la clôture du trajet. Un problème ? Signale-le dans les 24 h.';

  @override
  String get tripLeftEarly =>
      'Tu as terminé ton trajet avant la destination prévue : ta part est prélevée à la clôture. Un problème ? Signale-le dans les 24 h.';

  @override
  String get stopArrived => 'Arrivée';

  @override
  String get stopLeftEarly => 'Terminé avant l\'arrivée';

  @override
  String get confirmPresence => 'Valider ma présence';

  @override
  String get presenceDone => 'Présence validée. Bon trajet.';

  @override
  String get shareLocation => 'Partager ma position';

  @override
  String get finishRide => 'Terminer le trajet';

  @override
  String get openDeparture => 'Écran de départ';

  @override
  String get departureTitle => 'Départ';

  @override
  String get departureIntro =>
      'Vérifie l\'ordre des arrêts, puis démarre : tes passagers te verront arriver.';

  @override
  String get startRide => 'Démarrer le trajet';

  @override
  String get launchNavigation => 'Lancer la navigation';

  @override
  String get nextStop => 'Arrêt suivant';

  @override
  String get changeNavApp => 'Changer d\'application GPS';

  @override
  String get navAppChoose => 'Avec quelle application ?';

  @override
  String get navAppGoogleMaps => 'Google Maps';

  @override
  String get navAppWaze => 'Waze';

  @override
  String get navAppAppleMaps => 'Plans';

  @override
  String get navAppNone => 'Aucune application GPS trouvée sur ce téléphone.';

  @override
  String get navOpenFailed => 'Impossible d\'ouvrir l\'application GPS.';

  @override
  String get wazeStopByStop => 'Waze ne prend qu\'une destination : tu iras d\'arrêt en arrêt.';

  @override
  String get pickedUp => 'Monté';

  @override
  String get markPickedUp => 'Monté à bord';

  @override
  String pickedUpSemantic(String name) {
    return 'Marquer $name comme monté à bord';
  }

  @override
  String get destination => 'Destination';

  @override
  String get locationTitle => 'Partage ta position pendant le trajet';

  @override
  String get locationBody =>
      'Les participants de ce trajet voient où tu es, seulement pendant le trajet. Le partage s\'arrête à l\'arrivée. Ta position valide aussi ta présence, ce qui déclenche le paiement.';

  @override
  String get locationBackground =>
      'Pour que le suivi continue écran éteint, une notification reste affichée pendant le trajet.';

  @override
  String get locationAllow => 'Autoriser la position';

  @override
  String get locationLater => 'Plus tard';

  @override
  String get locationDenied =>
      'Sans ta position, le suivi et la validation de présence ne marchent pas. Active-la pour Uni-Moov dans les réglages du téléphone.';

  @override
  String get locationOpenSettings => 'Ouvrir les réglages';

  @override
  String get locationNotificationTitle => 'Trajet Uni-Moov en cours';

  @override
  String get locationNotificationText =>
      'Ta position est partagée avec ton trajet jusqu\'à l\'arrivée.';

  @override
  String get profileWallet => 'Portefeuille';

  @override
  String get walletTitle => 'Ton portefeuille';

  @override
  String get walletIntro => 'Tes trajets sont payés depuis ce solde, sans frais à chaque trajet.';

  @override
  String get walletBalance => 'Disponible';

  @override
  String walletPending(String amount) {
    return '$amount reçus, versés après 24 h sans signalement';
  }

  @override
  String walletHeld(String amount) {
    return '$amount retenus pour un trajet en cours';
  }

  @override
  String walletTopup(String amount) {
    return 'Recharger $amount';
  }

  @override
  String get walletTopupDone => 'Portefeuille rechargé.';

  @override
  String get walletHistory => 'Historique';

  @override
  String get walletEmpty => 'Aucune opération pour l\'instant.';

  @override
  String get walletKindTopup => 'Recharge';

  @override
  String get walletKindRideCharge => 'Trajet payé';

  @override
  String get walletKindRideCredit => 'Trajet reçu';

  @override
  String get walletKindPayout => 'Retrait';

  @override
  String get walletKindRefund => 'Remboursement';

  @override
  String get walletFake => 'Mode test : aucun argent réel n\'est prélevé.';

  @override
  String get errorTooEarly => 'Trop tôt pour démarrer ce trajet.';

  @override
  String get errorRideNotStarted => 'Le trajet n\'a pas encore commencé.';

  @override
  String get errorPresenceNotConfirmed =>
      'Ton téléphone et celui du conducteur doivent être proches.';

  @override
  String get errorTopupTooSmall => 'Montant de recharge trop faible.';

  @override
  String get errorTopupFailed => 'La recharge a été refusée.';

  @override
  String get finishConfirmTitle => 'Terminer le trajet ?';

  @override
  String get finishConfirmBody =>
      'Le suivi s\'arrête pour tout le monde. Les passagers pris en charge paient leur part ; ta part est versée après 24 h, sauf si un problème est signalé.';

  @override
  String get finishConfirmCancel => 'Continuer le trajet';

  @override
  String get finishMyTrip => 'Terminer mon trajet';

  @override
  String get finishMyTripTitle => 'Terminer ton trajet maintenant ?';

  @override
  String get finishMyTripBody =>
      'Tu n\'as pas encore atteint la destination prévue. Tu as été pris en charge : ta part reste due, même si tu descends ailleurs. Le conducteur est prévenu tout de suite. Un problème ? Signale-le après le trajet, dans les 24 h.';

  @override
  String get finishMyTripConfirm => 'Terminer quand même';

  @override
  String get finishMyTripDone => 'Trajet terminé. Le conducteur est prévenu.';

  @override
  String get insufficientFundsTitle => 'Solde insuffisant';

  @override
  String get insufficientFundsBody =>
      'Ton solde ne couvre pas le prix maximal de ce trajet. Recharge ton portefeuille pour le réserver : tu ne paieras à l\'arrivée que ta part réelle.';

  @override
  String get insufficientFundsTopup => 'Recharger';

  @override
  String get insufficientFundsLater => 'Plus tard';

  @override
  String get walletPayout => 'Retirer vers mon compte';

  @override
  String get walletPayoutTitle => 'Retirer ton solde';

  @override
  String get walletPayoutIntro =>
      'Le virement part vers ton compte bancaire. Uni-Moov ne garde que les 4 derniers chiffres de ton IBAN.';

  @override
  String get walletPayoutAmount => 'Montant en euros';

  @override
  String get walletPayoutIban => 'IBAN';

  @override
  String get walletPayoutHolder => 'Titulaire du compte';

  @override
  String walletPayoutSubmit(String amount) {
    return 'Retirer $amount';
  }

  @override
  String get walletPayoutDone => 'Retrait demandé. Le virement arrive sous quelques jours.';

  @override
  String walletPayoutRule(String amount) {
    return 'Un retrait par semaine, $amount minimum.';
  }

  @override
  String get walletPayoutAmountInvalid => 'Indique un montant, par exemple 12,50.';

  @override
  String get walletPayoutHolderInvalid => 'Indique le nom du titulaire du compte.';

  @override
  String get errorIbanInvalid => 'Cet IBAN n\'est pas valide : vérifie-le.';

  @override
  String get errorPayoutTooSmall => 'Montant de retrait trop faible.';

  @override
  String get errorPayoutTooSoon => 'Un seul retrait par semaine : réessaie plus tard.';

  @override
  String get errorPayoutFailed => 'Le virement a été refusé.';

  @override
  String get errorInsufficientFunds => 'Solde insuffisant.';

  @override
  String get errorNotOnBoard => 'Ta présence n\'est pas validée : pour renoncer, annule ta place.';

  @override
  String get cancelMyPlace => 'Annuler ma place';

  @override
  String get cancelRide => 'Annuler le trajet';

  @override
  String get cancelSheetTitle => 'Annuler ce trajet ?';

  @override
  String get cancelTierEarly => 'Tu préviens tôt : ton score baisse un peu.';

  @override
  String get cancelTierMedium => 'Le départ approche : ton score baisse davantage.';

  @override
  String get cancelTierLate => 'Départ imminent : ton score baisse nettement.';

  @override
  String get cancelPassengerEffect =>
      'Le conducteur est prévenu et ta place est proposée à quelqu\'un d\'autre.';

  @override
  String get cancelDriverEffect =>
      'Tes passagers sont prévenus et on leur cherche une autre voiture.';

  @override
  String get cancelKeep => 'Garder mon trajet';

  @override
  String get cancelDone => 'Trajet annulé.';

  @override
  String get ratingTitle => 'Noter le trajet';

  @override
  String get ratingIntro => 'Facultatif. Ta note compte dans le score de fiabilité de la personne.';

  @override
  String ratingStar(int stars, String name) {
    return '$stars sur 5 pour $name';
  }

  @override
  String ratingGiven(int stars) {
    return 'Ta note : $stars sur 5';
  }

  @override
  String get ratingDone => 'Note enregistrée.';

  @override
  String get ratingClosed => 'La notation de ce trajet est fermée.';

  @override
  String get ratingDriver => 'Conducteur';

  @override
  String get ratingPassenger => 'Passager';

  @override
  String get profileReliability => 'Fiabilité';

  @override
  String get reliabilityTitle => 'Ma fiabilité';

  @override
  String reliabilityIntro(int days) {
    return 'Ton score aide à composer des trajets fiables, il ne t\'exclut jamais. Il se calcule sur les $days derniers jours.';
  }

  @override
  String reliabilityScore(String score) {
    return '$score sur 5';
  }

  @override
  String get reliabilityScoreLabel => 'Score de fiabilité';

  @override
  String reliabilityCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trajets menés à bien',
      one: '1 trajet mené à bien',
      zero: 'Aucun trajet mené à bien',
    );
    return '$_temp0';
  }

  @override
  String reliabilityCancellations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annulations',
      one: '1 annulation',
      zero: 'Aucune annulation',
    );
    return '$_temp0';
  }

  @override
  String reliabilityNoShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count absences',
      one: '1 absence',
      zero: 'Aucune absence',
    );
    return '$_temp0';
  }

  @override
  String reliabilityRatings(int count, String average) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes, moyenne $average sur 5',
      one: '1 note, $average sur 5',
    );
    return '$_temp0';
  }

  @override
  String get reliabilityNoRatings => 'Pas encore de note';

  @override
  String get reliabilityEventsTitle => 'Ce qui a compté dans ton score';

  @override
  String reliabilityEmpty(int days) {
    return 'Aucune annulation ni absence sur les $days derniers jours.';
  }

  @override
  String get eventCancelEarly => 'Annulation prévenue tôt';

  @override
  String get eventCancelMedium => 'Annulation peu avant le départ';

  @override
  String get eventCancelLate => 'Annulation au dernier moment';

  @override
  String get eventNoShow => 'Absence au rendez-vous';

  @override
  String get eventCorrection => 'Pénalité corrigée après vérification';

  @override
  String eventRideOn(String day) {
    return 'Trajet du $day';
  }

  @override
  String get contest => 'Contester';

  @override
  String get rideProblem => 'Un problème sur ce trajet ?';

  @override
  String get rideAbsent => 'Ta présence n\'a pas été validée : ce trajet compte comme une absence.';

  @override
  String get disputeTitle => 'Un problème sur ce trajet ?';

  @override
  String get disputeIntro =>
      'On vérifie d\'abord ce que l\'app a enregistré : heure d\'annulation, présence au rendez-vous. Si ça ne suffit pas, l\'équipe Uni-Moov te répond par mail.';

  @override
  String get disputeReasonLabel => 'Motif';

  @override
  String get disputeReasonCancellation => 'Je conteste la pénalité d\'annulation';

  @override
  String get disputeReasonAbsent => 'Mon absence est une erreur';

  @override
  String get disputeReasonPayment => 'Un souci de paiement';

  @override
  String get disputeReasonDriver => 'Un souci avec le conducteur';

  @override
  String get disputeReasonOther => 'Autre chose';

  @override
  String get disputeMessageLabel => 'Explique en quelques mots (facultatif)';

  @override
  String get disputeSend => 'Envoyer';

  @override
  String get disputeYours => 'Tes demandes sur ce trajet';

  @override
  String get disputeWithTeam => 'Transmis à l\'équipe Uni-Moov, réponse par mail.';

  @override
  String get disputeEscalate => 'Je ne suis pas d\'accord';

  @override
  String get disputeEscalated => 'Demande transmise à l\'équipe.';

  @override
  String get disputeUpheld => 'Décision maintenue';

  @override
  String get disputeCorrected => 'Corrigé';

  @override
  String get disputePending => 'En cours d\'examen';

  @override
  String get explainPenaltyMatches =>
      'Les horodatages confirment l\'heure de ton annulation : la pénalité est maintenue.';

  @override
  String get explainPenaltyRecomputed =>
      'La pénalité ne correspondait pas aux horodatages : elle est corrigée.';

  @override
  String get explainNoPenalty => 'Aucune pénalité n\'a été appliquée pour ce trajet.';

  @override
  String get explainPresenceValidated =>
      'Ta présence avait bien été validée : la pénalité est retirée.';

  @override
  String get explainDriverConfirmed =>
      'Le conducteur t\'a déclaré à bord sans validation par GPS : l\'équipe va trancher.';

  @override
  String get explainNoPresence =>
      'Aucune validation de présence n\'a été enregistrée : l\'absence est maintenue.';

  @override
  String get explainNotAbsent => 'Aucune absence n\'est enregistrée pour toi sur ce trajet.';

  @override
  String get explainNeedsHuman => 'L\'équipe Uni-Moov examine ta demande et te répond par mail.';

  @override
  String get reportAction => 'Signaler une personne';

  @override
  String get reportIntro =>
      'Ton signalement reste confidentiel : seule l\'équipe Uni-Moov le lit et peut te recontacter par mail.';

  @override
  String get reportWho => 'Qui ?';

  @override
  String get reportWhy => 'Pourquoi ?';

  @override
  String get reportDangerous => 'Conduite dangereuse';

  @override
  String get reportInappropriate => 'Comportement déplacé';

  @override
  String get reportFake => 'Faux profil';

  @override
  String get reportOther => 'Autre chose';

  @override
  String get reportSend => 'Envoyer le signalement';

  @override
  String get reportDone => 'Signalement envoyé.';

  @override
  String get errorNotAccepted => 'Tu n\'as pas accepté ce trajet.';

  @override
  String get errorAlreadyRated => 'Tu as déjà noté cette personne.';

  @override
  String get errorNotRateable => 'Tu ne peux pas noter cette personne pour ce trajet.';

  @override
  String get errorRatingClosed => 'La notation de ce trajet est fermée.';

  @override
  String get errorRideNotCompleted => 'Ce trajet n\'est pas terminé.';

  @override
  String get errorDisputeExists => 'Tu as déjà signalé ce problème pour ce trajet.';

  @override
  String get errorDisputeClosed => 'Le délai pour signaler un problème sur ce trajet est passé.';

  @override
  String get errorDisputeNotApplicable => 'Ce motif ne correspond pas à ce trajet.';

  @override
  String get errorReportLimit => 'Tu as atteint le nombre de signalements du jour.';

  @override
  String ratingSend(int stars) {
    return 'Envoyer ma note ($stars sur 5)';
  }

  @override
  String get cancelSheetTitlePassenger => 'Annuler ta place ?';

  @override
  String get cancelDonePassenger => 'Ta place est annulée.';

  @override
  String get eventContestClosed => 'Délai de contestation dépassé.';

  @override
  String get disputeWhy => 'Dis-nous pourquoi (facultatif)';

  @override
  String get disputeSendTeam => 'Envoyer à l\'équipe';

  @override
  String get disputeAnother => 'Signaler un autre problème';

  @override
  String get disputeChooseReason => 'Choisis un motif pour continuer.';

  @override
  String get reportEmergency => 'En cas de danger immédiat, appelle le 112.';

  @override
  String get chatTitle => 'Messages';

  @override
  String get chatNew => 'Nouveau message';

  @override
  String get chatNewIntro =>
      'Tu peux écrire aux personnes croisées sur un trajet. Choisis-en plusieurs pour créer un groupe.';

  @override
  String get chatNoContacts =>
      'Personne pour l\'instant. Après ton premier trajet, tu pourras écrire aux personnes croisées.';

  @override
  String get chatEmpty =>
      'Pas encore de conversation. Le chat de ton trajet apparaît ici dès qu\'il est confirmé.';

  @override
  String get chatGroup => 'Groupe';

  @override
  String get chatGroupName => 'Nom du groupe';

  @override
  String get chatCreateGroup => 'Créer le groupe';

  @override
  String get chatStart => 'Écrire';

  @override
  String get chatRideTitle => 'Chat du trajet';

  @override
  String chatWith(String names) {
    return 'Avec $names';
  }

  @override
  String chatYouSaid(String body) {
    return 'Toi : $body';
  }

  @override
  String chatUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lus',
      one: '1 non lu',
    );
    return '$_temp0';
  }

  @override
  String get chatArchived => 'Archivé';

  @override
  String get chatArchivedBody =>
      'Ce chat de trajet est archivé : tu peux le relire, plus y écrire.';

  @override
  String get chatNoMessages => 'Aucun message pour l\'instant. Lance la conversation.';

  @override
  String get chatOlder => 'Voir les messages plus anciens';

  @override
  String get chatMessageLabel => 'Écris un message';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatLeave => 'Quitter le groupe';

  @override
  String get chatFormerMember => 'Ancien membre';

  @override
  String chatMineSemantic(String body, String time) {
    return 'Toi, $time : $body';
  }

  @override
  String chatTheirsSemantic(String name, String body, String time) {
    return '$name, $time : $body';
  }

  @override
  String get chatMessagesTooltip => 'Messages';

  @override
  String chatMessagesUnreadTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Messages, $count non lus',
      one: 'Messages, 1 non lu',
    );
    return '$_temp0';
  }

  @override
  String get rideChat => 'Chat du trajet';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsIntro => 'Tout est activé par défaut. Coupe ce dont tu n\'as pas besoin.';

  @override
  String get notificationsRideReminder => 'Rappel de trajet';

  @override
  String get notificationsRideReminderHelp => 'Une heure avant le départ.';

  @override
  String get notificationsRideUpdate => 'Changements de trajet';

  @override
  String get notificationsRideUpdateHelp => 'Annulation, conducteur qui se désiste.';

  @override
  String get notificationsMatch => 'Propositions';

  @override
  String get notificationsMatchHelp => 'Ta semaine prête, une place qui se libère.';

  @override
  String get notificationsChat => 'Messages';

  @override
  String get notificationsChatHelp => 'Nouveau message dans une conversation.';

  @override
  String get errorNotAContact => 'Tu ne peux écrire qu\'aux personnes croisées sur un trajet.';

  @override
  String get errorConversationArchived => 'Cette conversation est archivée.';

  @override
  String get errorGroupTooLarge => 'Ce groupe compte trop de personnes.';

  @override
  String get chatToday => 'Aujourd\'hui';

  @override
  String get chatYesterday => 'Hier';

  @override
  String get chatSeeRide => 'Voir le trajet';

  @override
  String get chatLeaveTitle => 'Quitter le groupe ?';

  @override
  String get chatLeaveBody => 'Tu ne verras plus ses messages.';

  @override
  String get chatLeaveConfirm => 'Quitter';

  @override
  String get chatGroupNameHelp => 'Obligatoire pour un groupe.';

  @override
  String get chatLeaveCancel => 'Rester';

  @override
  String get notificationsBlockedTitle => 'Notifications bloquées';

  @override
  String get notificationsBlockedBody =>
      'Ton téléphone bloque les notifications d\'Uni-Moov. Tu ne recevras ni rappel de trajet ni message.';

  @override
  String get exportAction => 'Exporter mes données';

  @override
  String get exportSubject => 'Mes données Uni-Moov';

  @override
  String get deleteAccountAction => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer ton compte';

  @override
  String get deleteAccountIntro => 'C\'est définitif : ton compte ne pourra pas être récupéré.';

  @override
  String get deleteAccountErased =>
      'ton nom, ton mail, ton adresse, ton véhicule, ton agenda, tes messages et tes appareils.';

  @override
  String get deleteAccountKept =>
      'les trajets passés, les paiements et les notes, pour la comptabilité et les litiges.';

  @override
  String get deleteAccountRides => 'tes trajets à venir. Les autres sont prévenus.';

  @override
  String get deleteAccountPassword => 'Ton mot de passe, pour confirmer';

  @override
  String get deleteAccountConfirm => 'Supprimer définitivement';

  @override
  String get deleteAccountCancel => 'Garder mon compte';

  @override
  String get deleteAccountDone => 'Ton compte est supprimé.';

  @override
  String get errorInvalidPassword => 'Mot de passe incorrect. Réessaie.';

  @override
  String get errorWalletNotEmpty =>
      'Ton portefeuille n\'est pas vide : récupère ton solde avant de supprimer ton compte.';

  @override
  String get errorRideInProgress => 'Termine ton trajet en cours avant de supprimer ton compte.';

  @override
  String get deleteAccountErasedLead => 'Effacés :';

  @override
  String get deleteAccountKeptLead => 'Gardés sans ton nom :';

  @override
  String get deleteAccountRidesLead => 'Annulés :';

  @override
  String get deleteAccountWalletTitle => 'Portefeuille à vider d\'abord';

  @override
  String deleteAccountWalletLeft(String amount, String email) {
    return 'Il te reste $amount sur ton portefeuille. Retire-les vers ton compte bancaire (ou écris à l\'équipe, $email), puis reviens supprimer ton compte.';
  }

  @override
  String get deleteAccountWriteTeam => 'Écrire à l\'équipe';

  @override
  String get deleteAccountMailSubject => 'Récupérer mon solde avant de supprimer mon compte';

  @override
  String get exportDone => 'Tes données sont prêtes.';

  @override
  String get notificationsOpenSettings => 'Ouvrir les réglages';

  @override
  String get notificationsBlockedHelp =>
      'Ces choix s\'appliqueront dès que tu auras réactivé les notifications.';

  @override
  String noMailApp(String email) {
    return 'Aucune application de mail trouvée. Écris-nous à $email.';
  }

  @override
  String get requestSent => 'Demande envoyée';

  @override
  String get requestWithdraw => 'Retirer ma demande';

  @override
  String get requestApprove => 'Accepter';

  @override
  String get requestReject => 'Refuser';

  @override
  String get homePlace => 'Domicile';

  @override
  String rideSeatsTaken(int taken, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      taken,
      locale: localeName,
      other: '$taken passagers',
      one: '1 passager',
      zero: 'Aucun passager',
    );
    return '$_temp0 sur $total places';
  }

  @override
  String homeBalance(String amount) {
    return 'Solde : $amount. Ouvrir le portefeuille';
  }

  @override
  String get rideStatusLive => 'En cours';

  @override
  String get historyTitle => 'Historique';

  @override
  String get historyEmpty => 'Tes trajets terminés apparaîtront ici.';

  @override
  String get historyAbsent => 'Absent';

  @override
  String get roleAutoInfoTooltip => 'Comment marche le mode automatique';

  @override
  String get roleAutoInfo =>
      'Chaque jour, Uni-Moov regarde les besoins de ton secteur. S\'il manque un conducteur, tu conduis ; sinon tu montes avec quelqu\'un. Entre plusieurs conducteurs possibles, on alterne : celui qui a le moins conduit ces dernières semaines prend le volant. Tes pauses programmées sont toujours respectées.';

  @override
  String get understood => 'Compris';

  @override
  String tripTitleTo(String date) {
    return 'Aller · $date';
  }

  @override
  String tripTitleFrom(String date) {
    return 'Retour · $date';
  }

  @override
  String statScore(String score) {
    return 'Note : $score sur 5';
  }

  @override
  String statDetour(int minutes) {
    return '+$minutes min';
  }

  @override
  String statDetourDriver(int minutes) {
    return 'Fait $minutes minutes de détour pour toi';
  }

  @override
  String statDetourPassenger(int minutes) {
    return 'Te fait faire $minutes minutes de détour';
  }

  @override
  String get personAccepted => 'Accepté';

  @override
  String get personRequested => 'Demande';

  @override
  String get personPending => 'En attente';

  @override
  String get priceBulletFinal => 'Prix final calculé à l\'arrivée';

  @override
  String get stopOnBoard => 'À bord';

  @override
  String get moreActions => 'Plus d\'actions';

  @override
  String get rideDetailsTitle => 'Détails du trajet';

  @override
  String proposalMapLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Carte du trajet proposé, $count personnes en zones approximatives',
      one: 'Carte du trajet proposé, 1 personne en zone approximative',
      zero: 'Carte du trajet proposé',
    );
    return '$_temp0';
  }

  @override
  String get chatRideBar => 'Ton trajet';

  @override
  String get aboutTitle => 'À propos de moi';

  @override
  String get aboutIntro =>
      'Visible par les étudiants que tu croises sur un trajet. Tout est facultatif.';

  @override
  String get aboutEmpty => 'Formation, âge, centres d\'intérêt';

  @override
  String get aboutStudy => 'Formation';

  @override
  String get aboutStudyHint => 'BUT Informatique';

  @override
  String get aboutBirthYear => 'Année de naissance';

  @override
  String get aboutBirthYearHelp => 'Seul ton âge est affiché.';

  @override
  String get aboutBirthYearInvalid => 'Indique une année, par exemple 2005.';

  @override
  String get aboutInterests => 'Centres d\'intérêt';

  @override
  String get aboutInterestAdd => 'Ajouter un centre d\'intérêt';

  @override
  String get aboutInterestHint => 'Escalade';

  @override
  String aboutInterestRemove(String interest) {
    return 'Retirer $interest';
  }

  @override
  String ageYears(int age) {
    return '$age ans';
  }

  @override
  String profileNameAge(String name, int age) {
    return '$name, $age ans';
  }

  @override
  String get profileSeeMine => 'Voir mon profil comme les autres';

  @override
  String get profileUnavailable => 'Ce profil n\'est pas disponible.';

  @override
  String statRides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trajets menés à bien',
      one: '1 trajet mené à bien',
      zero: 'Aucun trajet mené',
    );
    return '$_temp0';
  }

  @override
  String get photoChange => 'Changer ma photo';

  @override
  String get photoFromGallery => 'Choisir une photo';

  @override
  String get photoFromCamera => 'Prendre une photo';

  @override
  String get photoRemove => 'Retirer la photo';

  @override
  String get photoSaved => 'Photo enregistrée.';

  @override
  String get photoUnavailable =>
      'Impossible d\'ouvrir tes photos. Vérifie l\'autorisation dans les réglages.';

  @override
  String get errorPhotoInvalid => 'Choisis une photo JPEG ou PNG.';

  @override
  String get carpoolTitle => 'Proposer un covoiturage';

  @override
  String get carpoolIDrive => 'Je conduis';

  @override
  String get carpoolILook => 'Je cherche';

  @override
  String carpoolSeats(int count) {
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
  String get carpoolToCampus => 'Aller';

  @override
  String get carpoolFromCampus => 'Retour';

  @override
  String get carpoolAsk => 'Publier ma demande';

  @override
  String get carpoolOffer => 'Trajet proposé';

  @override
  String get carpoolRequest => 'Cherche un trajet';

  @override
  String get carpoolJoin => 'Je monte';

  @override
  String get carpoolTake => 'Je te prends';

  @override
  String carpoolJoined(String names) {
    return '$names : c\'est réservé';
  }

  @override
  String get carpoolDone => 'C\'est réservé : le trajet est dans ta semaine.';

  @override
  String get errorNoRideThatDay =>
      'Tu ne conduis pas ce jour-là. Accepte d\'abord un trajet comme conducteur.';

  @override
  String get errorOwnCarpool => 'C\'est ta propre proposition.';

  @override
  String get errorCarpoolNotHere => 'Propose un trajet dans un groupe ou une conversation privée.';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeSystem => 'Automatique (comme le téléphone)';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get reduceMotion => 'Réduire les animations';

  @override
  String get ridePriceReceiveTotalLabel => 'Tu reçois au total';

  @override
  String ridePriceYouReceiveTotal(String price, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passagers',
      one: '1 passager',
      zero: 'personne',
    );
    return 'Tu reçois $price au total, de $_temp0';
  }

  @override
  String ridePriceFromPassengers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Somme payée par tes $count passagers',
      one: 'Payé par ton passager',
    );
    return '$_temp0';
  }

  @override
  String get calcTitle => 'Détail du calcul';

  @override
  String calcLitres(String km, String consumption, String litres) {
    return '$km km × $consumption L/100 km = $litres L';
  }

  @override
  String calcFuel(String litres, String price) {
    return '$litres L × $price le litre';
  }

  @override
  String calcPortion(String km, int persons) {
    return '$km km à $persons (conducteur compris)';
  }

  @override
  String calcShareOf(String name) {
    return 'Part de $name';
  }

  @override
  String get calcMyShare => 'Ta part du carburant';

  @override
  String get calcCommission => 'Frais de service';

  @override
  String get calcTotalPaid => 'Tu paies';

  @override
  String get calcTotalReceived => 'Tu reçois';

  @override
  String get carpoolArriveAt => 'Arrivée au campus';

  @override
  String get carpoolLeaveAt => 'Départ du campus';

  @override
  String get carpoolReturnAt => 'Retour, départ du campus';

  @override
  String get carpoolWithReturn => 'Programmer le retour';

  @override
  String get carpoolPublishDrive => 'Proposer ce trajet';

  @override
  String get carpoolExisting => 'Ou un trajet déjà prévu';

  @override
  String get vehicleModelLabel => 'Modèle';

  @override
  String get vehicleModelHint => 'Renault Clio';

  @override
  String get vehicleModelRequired =>
      'Indique le modèle, pour que tes passagers reconnaissent ta voiture.';

  @override
  String get vehicleColorLabel => 'Couleur';

  @override
  String get vehicleColorRequired => 'Indique la couleur de ta voiture.';

  @override
  String get vehicleColorChoices =>
      'blanche,noire,grise,argent,bleue,rouge,verte,beige,marron,jaune,orange';

  @override
  String rideVehicleSemantic(String description) {
    return 'Voiture : $description';
  }

  @override
  String get rideCardReceive => 'Tu reçois';

  @override
  String proposalPricePay(String price) {
    return 'Environ $price pour toi';
  }

  @override
  String proposalPriceReceive(String price) {
    return 'Tu reçois environ $price au total';
  }

  @override
  String get chatAttach => 'Joindre une photo ou un trajet';

  @override
  String get chatPhotoSemantic => 'Photo';

  @override
  String get chatReact => 'Réagir';

  @override
  String chatReactWith(String emoji) {
    return 'Réagir avec $emoji';
  }

  @override
  String get chatReactionRemove => 'Retirer ma réaction';

  @override
  String chatReactionSemantic(String emoji, int count) {
    return 'Réaction $emoji, $count';
  }

  @override
  String chatReactionMineSemantic(String emoji, int count) {
    return 'Ta réaction $emoji, $count. Touche pour la retirer';
  }

  @override
  String get chatLastPhoto => 'Photo';

  @override
  String get close => 'Fermer';

  @override
  String get achievementsTitle => 'Mes réussites';

  @override
  String get levelNewcomer => 'Nouvel Uni-Mooveur';

  @override
  String get levelRegular => 'Habitué';

  @override
  String get levelPillar => 'Pilier du campus';

  @override
  String get levelSuper => 'Super Uni-Mooveur';

  @override
  String get levelLegend => 'Légende du campus';

  @override
  String get levelTop => 'Tu as atteint le plus haut niveau.';

  @override
  String levelNext(int count, String level) {
    return 'Encore $count points pour devenir $level';
  }

  @override
  String pointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
      zero: '0 point',
    );
    return '$_temp0';
  }

  @override
  String pointsShort(int count) {
    return '$count pts';
  }

  @override
  String get impactCo2 => 'de CO2 évités';

  @override
  String get impactKm => 'partagés';

  @override
  String get impactRides => 'trajets effectués';

  @override
  String get impactReceived => 'reçus en conducteur';

  @override
  String get impactPaid => 'payés en passager';

  @override
  String badgesTitle(int earned, int total) {
    return 'Badges ($earned/$total)';
  }

  @override
  String get badgeEarned => 'Gagné';

  @override
  String badgeProgress(int progress, int goal) {
    return '$progress/$goal';
  }

  @override
  String get badgeFirstRide => 'Premier trajet';

  @override
  String get badgeFirstRideGoal => 'Fais ton premier trajet.';

  @override
  String get badgeTenRides => '10 trajets';

  @override
  String get badgeTenRidesGoal => 'Fais 10 trajets.';

  @override
  String get badgeFiftyRides => '50 trajets';

  @override
  String get badgeFiftyRidesGoal => 'Fais 50 trajets.';

  @override
  String get badgeLoyalDriver => 'Conducteur fidèle';

  @override
  String get badgeLoyalDriverGoal => 'Conduis 10 trajets avec des passagers.';

  @override
  String get badgeFullWeek => 'Semaine complète';

  @override
  String get badgeFullWeekGoal => 'Fais 5 trajets dans la même semaine.';

  @override
  String get badgeSociable => 'Sociable';

  @override
  String get badgeSociableGoal => 'Voyage avec 10 personnes différentes.';

  @override
  String get badgeEco => 'Éco-voyageur';

  @override
  String get badgeEcoGoal => 'Évite 100 kg de CO2.';

  @override
  String get badgeReliable => 'Fiable';

  @override
  String get badgeReliableGoal => 'Fais 5 trajets avec une fiabilité d\'au moins 95 %.';

  @override
  String get leaderboardTitle => 'Classement du campus';

  @override
  String leaderboardTitleMonth(String month) {
    return 'Classement du campus en $month';
  }

  @override
  String get leaderboardShowMe => 'Apparaître avec mon prénom';

  @override
  String get leaderboardShowMeHelp => 'Sinon, tu restes classé, mais anonyme.';

  @override
  String get leaderboardEmpty =>
      'Personne n\'a encore de points ce mois-ci. Un trajet suffit pour entrer au classement.';

  @override
  String leaderboardMyRank(int rank, int total) {
    return 'Ta place : $rank sur $total';
  }

  @override
  String get leaderboardError => 'Classement indisponible pour l\'instant.';

  @override
  String get leaderboardYou => 'Toi';

  @override
  String get leaderboardAnonymous => 'Un étudiant';

  @override
  String leaderboardRowSemantic(int rank, String name, int points) {
    return '${rank}e, $name, $points points';
  }

  @override
  String get sectionAbout => 'Mon profil';

  @override
  String get sectionActivity => 'Mon activité';

  @override
  String get sectionTrips => 'Mes trajets';

  @override
  String get sectionPauses => 'Pauses';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get sectionAccount => 'Compte et confidentialité';

  @override
  String get aboutBio => 'Mini-bio';

  @override
  String get aboutBioHint => 'Mes points de rendez-vous, ce que j\'aime en trajet…';

  @override
  String aboutInterestsHelp(int count, int max) {
    return 'Touche ceux qui te ressemblent ($count/$max).';
  }

  @override
  String get prefsTitle => 'Préférences de covoiturage';

  @override
  String get prefChatTitle => 'Discussion';

  @override
  String get prefChatChatty => 'J\'aime bien discuter';

  @override
  String get prefChatDepends => 'Je discute si je me sens à l\'aise';

  @override
  String get prefChatQuiet => 'Je préfère le calme';

  @override
  String get prefMusicTitle => 'Musique';

  @override
  String get prefMusicYes => 'J\'aime la musique en voiture';

  @override
  String get prefMusicDepends => 'J\'aime la musique si elle me plaît';

  @override
  String get prefMusicNo => 'Je préfère sans musique';

  @override
  String get prefSmokingTitle => 'Cigarette';

  @override
  String get prefSmokingOk => 'La cigarette ne me dérange pas';

  @override
  String get prefSmokingOutside => 'Pauses cigarette dehors seulement';

  @override
  String get prefSmokingNo => 'Je préfère qu\'on ne fume pas en voiture';

  @override
  String get prefPetsTitle => 'Animaux';

  @override
  String get prefPetsYes => 'J\'aime les animaux à bord';

  @override
  String get prefPetsSome => 'Je peux covoiturer avec certains animaux';

  @override
  String get prefPetsNo => 'Je préfère sans animaux';

  @override
  String profileRating(String score, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avis',
      one: '1 avis',
      zero: 'aucun avis',
    );
    return '$score/5 · $_temp0';
  }

  @override
  String profileWrite(String name) {
    return 'Écrire à $name';
  }

  @override
  String get profileEditMine => 'Modifier mon profil';

  @override
  String profileVerifiedTitle(String name) {
    return '$name a un profil vérifié';
  }

  @override
  String get profileVerifiedEmail => 'Mail universitaire vérifié';

  @override
  String profileMemberSince(String month) {
    return 'Membre depuis $month';
  }

  @override
  String profileAboutTitle(String name) {
    return 'À propos de $name';
  }

  @override
  String profileAboutEmpty(String name) {
    return '$name n\'a encore rien ajouté.';
  }

  @override
  String get profileBadges => 'Badges';

  @override
  String profileRides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trajets effectués',
      one: '1 trajet effectué',
      zero: 'Aucun trajet effectué',
    );
    return '$_temp0';
  }

  @override
  String profileCancellationRate(int rate) {
    return 'Taux d\'annulation de $rate %';
  }

  @override
  String profileCo2(int kg) {
    return '$kg kg de CO2 évités en covoiturant';
  }
}
