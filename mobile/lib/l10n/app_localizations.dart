import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Uni-Moov'**
  String get appTitle;

  /// No description provided for @logoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Logo Uni-Moov'**
  String get logoLabel;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @fieldErrorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get fieldErrorPrefix;

  /// No description provided for @fieldShowPassword.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get fieldShowPassword;

  /// No description provided for @fieldHidePassword.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get fieldHidePassword;

  /// No description provided for @rideFrom.
  ///
  /// In fr, this message translates to:
  /// **'Départ : {place}'**
  String rideFrom(String place);

  /// No description provided for @rideTo.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée : {place}'**
  String rideTo(String place);

  /// No description provided for @rideMeta.
  ///
  /// In fr, this message translates to:
  /// **'{time} · avec {driver}'**
  String rideMeta(String time, String driver);

  /// No description provided for @rideSeats.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Complet} =1{1 place libre} other{{count} places libres}}'**
  String rideSeats(int count);

  /// No description provided for @ridePriceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix estimé : {price}'**
  String ridePriceLabel(String price);

  /// No description provided for @rideStatusProposed.
  ///
  /// In fr, this message translates to:
  /// **'Proposé'**
  String get rideStatusProposed;

  /// No description provided for @rideStatusConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmé'**
  String get rideStatusConfirmed;

  /// No description provided for @rideStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get rideStatusCancelled;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton emploi du temps organise aussi tes trajets.'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Covoiturage domicile-campus pour les étudiants d\'Annecy'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeNote.
  ///
  /// In fr, this message translates to:
  /// **'Inscris-toi en deux minutes !'**
  String get welcomeNote;

  /// No description provided for @welcomeBenefitSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Trajets calés sur tes cours'**
  String get welcomeBenefitSchedule;

  /// No description provided for @welcomeBenefitPrice.
  ///
  /// In fr, this message translates to:
  /// **'Frais partagés au juste prix'**
  String get welcomeBenefitPrice;

  /// No description provided for @welcomeBenefitConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmé à deux, toujours'**
  String get welcomeBenefitConfirm;

  /// No description provided for @welcomeSignup.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get welcomeSignup;

  /// No description provided for @welcomeLogin.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get welcomeLogin;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get loading;

  /// No description provided for @continueAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueAction;

  /// No description provided for @skipForNow.
  ///
  /// In fr, this message translates to:
  /// **'Passer pour l\'instant'**
  String get skipForNow;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessaie.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible pour l\'instant. Vérifie ton réseau.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessaie dans quelques minutes.'**
  String get errorRateLimited;

  /// No description provided for @errorValidation.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie les informations saisies.'**
  String get errorValidation;

  /// No description provided for @errorSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Ta session a expiré. Connecte-toi à nouveau.'**
  String get errorSessionExpired;

  /// No description provided for @errorEmailDomain.
  ///
  /// In fr, this message translates to:
  /// **'Utilise ton adresse mail universitaire (univ-smb.fr).'**
  String get errorEmailDomain;

  /// No description provided for @errorCodeCooldown.
  ///
  /// In fr, this message translates to:
  /// **'Attends une minute avant de redemander un code.'**
  String get errorCodeCooldown;

  /// No description provided for @errorCodeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect ou expiré. Vérifie-le ou demande un nouveau code.'**
  String get errorCodeInvalid;

  /// No description provided for @errorAccountExists.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà un compte avec cette adresse. Connecte-toi.'**
  String get errorAccountExists;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Mail ou mot de passe incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAddressNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Adresse introuvable. Ajoute la ville ou le code postal.'**
  String get errorAddressNotFound;

  /// No description provided for @errorGeocodingUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Recherche d\'adresse indisponible. Réessaie plus tard ou passe cette étape.'**
  String get errorGeocodingUnavailable;

  /// No description provided for @errorVehicleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute un véhicule pour conduire.'**
  String get errorVehicleRequired;

  /// No description provided for @errorInvalidPause.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie les dates : la fin suit le début et la pause dure un an au plus.'**
  String get errorInvalidPause;

  /// No description provided for @errorTooManyPauses.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà programmé beaucoup de pauses. Supprimes-en une d\'abord.'**
  String get errorTooManyPauses;

  /// No description provided for @fieldEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Saisis une adresse mail valide.'**
  String get fieldEmailInvalid;

  /// No description provided for @fieldCodeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Le code contient 6 chiffres.'**
  String get fieldCodeInvalid;

  /// No description provided for @fieldPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères minimum.'**
  String get fieldPasswordTooShort;

  /// No description provided for @fieldRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire.'**
  String get fieldRequired;

  /// No description provided for @fieldNumberInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Saisis un nombre entre {min} et {max}.'**
  String fieldNumberInvalid(num min, num max);

  /// No description provided for @emailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mail universitaire'**
  String get emailLabel;

  /// No description provided for @emailPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'prenom.nom@etu.univ-smb.fr'**
  String get emailPlaceholder;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @passwordHelp.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères minimum.'**
  String get passwordHelp;

  /// No description provided for @firstNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstNameLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastNameLabel;

  /// No description provided for @signupEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Crée ton compte'**
  String get signupEmailTitle;

  /// No description provided for @signupEmailBody.
  ///
  /// In fr, this message translates to:
  /// **'Utilise ton adresse mail universitaire : on t\'envoie un code pour la vérifier.'**
  String get signupEmailBody;

  /// No description provided for @signupEmailAction.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir mon code'**
  String get signupEmailAction;

  /// No description provided for @signupCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ta boîte mail'**
  String get signupCodeTitle;

  /// No description provided for @signupCodeBody.
  ///
  /// In fr, this message translates to:
  /// **'Saisis le code à 6 chiffres envoyé à {email}. Il est valable 10 minutes. Pense à regarder dans tes spams.'**
  String signupCodeBody(String email);

  /// No description provided for @signupCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de confirmation'**
  String get signupCodeLabel;

  /// No description provided for @signupCodeResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get signupCodeResend;

  /// No description provided for @signupCodeResent.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code envoyé.'**
  String get signupCodeResent;

  /// No description provided for @signupChangeEmail.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'adresse'**
  String get signupChangeEmail;

  /// No description provided for @signupIdentityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Présente-toi'**
  String get signupIdentityTitle;

  /// No description provided for @signupIdentityBody.
  ///
  /// In fr, this message translates to:
  /// **'Les autres étudiants voient ton prénom. Ton nom n\'apparaît qu\'après un trajet confirmé à deux.'**
  String get signupIdentityBody;

  /// No description provided for @signupIdentityAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get signupIdentityAction;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Te revoilà'**
  String get loginTitle;

  /// No description provided for @loginAction.
  ///
  /// In fr, this message translates to:
  /// **'Me connecter'**
  String get loginAction;

  /// No description provided for @loginNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get loginNoAccount;

  /// No description provided for @splashError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger ton profil.'**
  String get splashError;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Me déconnecter'**
  String get signOut;

  /// No description provided for @onboardingProgress.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total}'**
  String onboardingProgress(int current, int total);

  /// No description provided for @addressTitle.
  ///
  /// In fr, this message translates to:
  /// **'Où habites-tu ?'**
  String get addressTitle;

  /// No description provided for @addressBody.
  ///
  /// In fr, this message translates to:
  /// **'Ton adresse sert à trouver des trajets près de chez toi. Avant un trajet confirmé à deux, les autres ne voient qu\'un secteur approximatif.'**
  String get addressBody;

  /// No description provided for @addressLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get addressLabel;

  /// No description provided for @addressPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'12 rue de la Paix, Annecy'**
  String get addressPlaceholder;

  /// No description provided for @addressFound.
  ///
  /// In fr, this message translates to:
  /// **'Adresse enregistrée : {address}'**
  String addressFound(String address);

  /// No description provided for @vehicleTitle.
  ///
  /// In fr, this message translates to:
  /// **'As-tu une voiture ?'**
  String get vehicleTitle;

  /// No description provided for @vehicleBody.
  ///
  /// In fr, this message translates to:
  /// **'Avec une voiture, tu peux conduire et partager les frais du trajet.'**
  String get vehicleBody;

  /// No description provided for @vehicleYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui, j\'ai une voiture'**
  String get vehicleYes;

  /// No description provided for @vehicleNo.
  ///
  /// In fr, this message translates to:
  /// **'Non, pas de voiture'**
  String get vehicleNo;

  /// No description provided for @vehicleConsumptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Consommation (L/100 km)'**
  String get vehicleConsumptionLabel;

  /// No description provided for @vehicleConsumptionHelp.
  ///
  /// In fr, this message translates to:
  /// **'Sert à calculer le partage des frais.'**
  String get vehicleConsumptionHelp;

  /// No description provided for @vehicleSeatsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Places passagers'**
  String get vehicleSeatsLabel;

  /// No description provided for @vehicleDetourLabel.
  ///
  /// In fr, this message translates to:
  /// **'Détour maximal (minutes)'**
  String get vehicleDetourLabel;

  /// No description provided for @vehicleDetourHelp.
  ///
  /// In fr, this message translates to:
  /// **'Uni-Moov ne te propose que des détours plus courts.'**
  String get vehicleDetourHelp;

  /// No description provided for @roleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quel rôle préfères-tu ?'**
  String get roleTitle;

  /// No description provided for @roleBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu pourras le changer quand tu veux depuis ton profil.'**
  String get roleBody;

  /// No description provided for @roleAuto.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get roleAuto;

  /// No description provided for @roleAutoHelp.
  ///
  /// In fr, this message translates to:
  /// **'Chaque semaine, Uni-Moov choisit si tu conduis ou non, selon les besoins.'**
  String get roleAutoHelp;

  /// No description provided for @roleDriver.
  ///
  /// In fr, this message translates to:
  /// **'Toujours au volant'**
  String get roleDriver;

  /// No description provided for @rolePassenger.
  ///
  /// In fr, this message translates to:
  /// **'Toujours côté passager'**
  String get rolePassenger;

  /// No description provided for @roleNoVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Sans voiture, tu voyages côté passager. Tu peux ajouter un véhicule plus tard dans ton profil.'**
  String get roleNoVehicle;

  /// No description provided for @calendarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton emploi du temps'**
  String get calendarTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Salut {firstName}'**
  String homeGreeting(String firstName);

  /// No description provided for @homeProfileTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get homeProfileTooltip;

  /// No description provided for @discoveryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode découverte'**
  String get discoveryTitle;

  /// No description provided for @discoveryBody.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute ton adresse pour recevoir des propositions de trajets.'**
  String get discoveryBody;

  /// No description provided for @discoveryAction.
  ///
  /// In fr, this message translates to:
  /// **'Compléter mon profil'**
  String get discoveryAction;

  /// No description provided for @pausedToday.
  ///
  /// In fr, this message translates to:
  /// **'En pause aujourd\'hui'**
  String get pausedToday;

  /// No description provided for @pauseAction.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get pauseAction;

  /// No description provided for @pauseManage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer mes pauses'**
  String get pauseManage;

  /// No description provided for @weekTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ta semaine'**
  String get weekTitle;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get profileTitle;

  /// No description provided for @profileIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get profileIdentity;

  /// No description provided for @profileAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get profileAddress;

  /// No description provided for @profileNoAddress.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse enregistrée.'**
  String get profileNoAddress;

  /// No description provided for @profileVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule'**
  String get profileVehicle;

  /// No description provided for @profileNoVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de véhicule.'**
  String get profileNoVehicle;

  /// No description provided for @profileVehicleSummary.
  ///
  /// In fr, this message translates to:
  /// **'{consumption} L/100 km · {seats} places · détour {detour} min'**
  String profileVehicleSummary(String consumption, int seats, int detour);

  /// No description provided for @profileRemoveVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le véhicule'**
  String get profileRemoveVehicle;

  /// No description provided for @profileRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get profileRole;

  /// No description provided for @profilePauses.
  ///
  /// In fr, this message translates to:
  /// **'Pauses'**
  String get profilePauses;

  /// No description provided for @profileNoPauses.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pause programmée.'**
  String get profileNoPauses;

  /// No description provided for @pauseRange.
  ///
  /// In fr, this message translates to:
  /// **'Du {start} au {end}'**
  String pauseRange(String start, String end);

  /// No description provided for @pauseAlternating.
  ///
  /// In fr, this message translates to:
  /// **'une semaine sur {weeks}'**
  String pauseAlternating(int weeks);

  /// No description provided for @pauseDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la pause du {start}'**
  String pauseDelete(String start);

  /// No description provided for @pauseSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get pauseSheetTitle;

  /// No description provided for @pauseSheetBody.
  ///
  /// In fr, this message translates to:
  /// **'Pendant une pause, tu ne reçois pas de propositions. Ton score de fiabilité n\'est pas touché.'**
  String get pauseSheetBody;

  /// No description provided for @pauseChooseDates.
  ///
  /// In fr, this message translates to:
  /// **'Choisir les dates'**
  String get pauseChooseDates;

  /// No description provided for @pauseAlternatingToggle.
  ///
  /// In fr, this message translates to:
  /// **'Une semaine sur deux (alternance)'**
  String get pauseAlternatingToggle;

  /// No description provided for @pauseSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la pause'**
  String get pauseSave;

  /// No description provided for @rideStatusWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get rideStatusWaiting;

  /// No description provided for @campusName.
  ///
  /// In fr, this message translates to:
  /// **'Campus d\'Annecy'**
  String get campusName;

  /// No description provided for @nearYourHome.
  ///
  /// In fr, this message translates to:
  /// **'Près de chez toi'**
  String get nearYourHome;

  /// No description provided for @yourHome.
  ///
  /// In fr, this message translates to:
  /// **'Chez toi'**
  String get yourHome;

  /// No description provided for @calendarBody.
  ///
  /// In fr, this message translates to:
  /// **'Uni-Moov lit ton emploi du temps pour te proposer tes trajets de la semaine. Choisis comment le partager.'**
  String get calendarBody;

  /// No description provided for @calendarChooseIcs.
  ///
  /// In fr, this message translates to:
  /// **'Coller mon lien d\'agenda (ICS)'**
  String get calendarChooseIcs;

  /// No description provided for @calendarChooseManual.
  ///
  /// In fr, this message translates to:
  /// **'Saisir mes horaires'**
  String get calendarChooseManual;

  /// No description provided for @icsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton lien d\'agenda'**
  String get icsTitle;

  /// No description provided for @icsBody.
  ///
  /// In fr, this message translates to:
  /// **'Copie le lien d\'abonnement (ICS) de ton emploi du temps, par exemple depuis ADE, puis colle-le ici.'**
  String get icsBody;

  /// No description provided for @icsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien ICS'**
  String get icsLabel;

  /// No description provided for @icsPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'https://…'**
  String get icsPlaceholder;

  /// No description provided for @icsConsent.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte qu\'Uni-Moov lise cet agenda pour n\'en garder que l\'heure de début et de fin de chaque journée. Les intitulés de cours ne sont pas conservés. Je peux le déconnecter à tout moment.'**
  String get icsConsent;

  /// No description provided for @icsConsentRequired.
  ///
  /// In fr, this message translates to:
  /// **'Coche la case pour autoriser la lecture de ton agenda.'**
  String get icsConsentRequired;

  /// No description provided for @icsConnect.
  ///
  /// In fr, this message translates to:
  /// **'Connecter mon agenda'**
  String get icsConnect;

  /// No description provided for @manualTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tes horaires de la semaine'**
  String get manualTitle;

  /// No description provided for @manualBody.
  ///
  /// In fr, this message translates to:
  /// **'Indique l\'heure de ton premier cours et la fin de ton dernier, pour chaque jour.'**
  String get manualBody;

  /// No description provided for @manualSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer mes horaires'**
  String get manualSave;

  /// No description provided for @manualStart.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get manualStart;

  /// No description provided for @manualEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get manualEnd;

  /// No description provided for @manualDayOff.
  ///
  /// In fr, this message translates to:
  /// **'Pas de cours'**
  String get manualDayOff;

  /// No description provided for @manualInvalid.
  ///
  /// In fr, this message translates to:
  /// **'La fin de journée doit suivre son début.'**
  String get manualInvalid;

  /// No description provided for @manualTimeLabel.
  ///
  /// In fr, this message translates to:
  /// **'{day}, {which} : {time}'**
  String manualTimeLabel(String day, String which, String time);

  /// No description provided for @weekday1.
  ///
  /// In fr, this message translates to:
  /// **'Lundi'**
  String get weekday1;

  /// No description provided for @weekday2.
  ///
  /// In fr, this message translates to:
  /// **'Mardi'**
  String get weekday2;

  /// No description provided for @weekday3.
  ///
  /// In fr, this message translates to:
  /// **'Mercredi'**
  String get weekday3;

  /// No description provided for @weekday4.
  ///
  /// In fr, this message translates to:
  /// **'Jeudi'**
  String get weekday4;

  /// No description provided for @weekday5.
  ///
  /// In fr, this message translates to:
  /// **'Vendredi'**
  String get weekday5;

  /// No description provided for @weekday6.
  ///
  /// In fr, this message translates to:
  /// **'Samedi'**
  String get weekday6;

  /// No description provided for @weekday7.
  ///
  /// In fr, this message translates to:
  /// **'Dimanche'**
  String get weekday7;

  /// No description provided for @errorCalendarUrl.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien n\'est pas valide. Il doit commencer par https://.'**
  String get errorCalendarUrl;

  /// No description provided for @errorCalendarUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ton agenda. Vérifie le lien ou réessaie plus tard.'**
  String get errorCalendarUnreachable;

  /// No description provided for @errorCalendarInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien ne renvoie pas un agenda. Copie le lien d\'abonnement (ICS).'**
  String get errorCalendarInvalid;

  /// No description provided for @errorDuplicateWeekday.
  ///
  /// In fr, this message translates to:
  /// **'Un même jour est saisi deux fois.'**
  String get errorDuplicateWeekday;

  /// No description provided for @errorProposalExpired.
  ///
  /// In fr, this message translates to:
  /// **'Cette proposition est passée.'**
  String get errorProposalExpired;

  /// No description provided for @errorProposalCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cette proposition a été annulée.'**
  String get errorProposalCancelled;

  /// No description provided for @errorRideUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Cette voiture ne peut plus te prendre. Choisis-en une autre.'**
  String get errorRideUnavailable;

  /// No description provided for @errorAlreadyCommitted.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà un trajet sur ce créneau.'**
  String get errorAlreadyCommitted;

  /// No description provided for @errorAlreadyDriving.
  ///
  /// In fr, this message translates to:
  /// **'Tu conduis déjà sur ce créneau.'**
  String get errorAlreadyDriving;

  /// No description provided for @errorAlreadyAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà répondu à cette proposition.'**
  String get errorAlreadyAnswered;

  /// No description provided for @errorSearchQuota.
  ///
  /// In fr, this message translates to:
  /// **'Tu as atteint le nombre de recherches du jour. Réessaie demain.'**
  String get errorSearchQuota;

  /// No description provided for @errorProfileIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute ton adresse pour trouver un trajet.'**
  String get errorProfileIncomplete;

  /// No description provided for @errorTimeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indique une heure pour ce jour.'**
  String get errorTimeRequired;

  /// No description provided for @weekThis.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get weekThis;

  /// No description provided for @weekNext.
  ///
  /// In fr, this message translates to:
  /// **'La suivante'**
  String get weekNext;

  /// No description provided for @weekEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de proposition cette semaine. Vérifie ton emploi du temps ou cherche un trajet.'**
  String get weekEmpty;

  /// No description provided for @weekEmptyNoSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute ton emploi du temps pour recevoir tes propositions.'**
  String get weekEmptyNoSchedule;

  /// No description provided for @addSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter mon emploi du temps'**
  String get addSchedule;

  /// No description provided for @searchAction.
  ///
  /// In fr, this message translates to:
  /// **'Chercher un trajet'**
  String get searchAction;

  /// No description provided for @directionTo.
  ///
  /// In fr, this message translates to:
  /// **'Aller'**
  String get directionTo;

  /// No description provided for @directionFrom.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get directionFrom;

  /// No description provided for @rideMetaDriver.
  ///
  /// In fr, this message translates to:
  /// **'{time} · tu conduis · {count, plural, =0{aucun passager pour l\'instant} =1{1 passager} other{{count} passagers}}'**
  String rideMetaDriver(String time, int count);

  /// No description provided for @see.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get see;

  /// No description provided for @proposalTitleTo.
  ///
  /// In fr, this message translates to:
  /// **'Aller du {day}'**
  String proposalTitleTo(String day);

  /// No description provided for @proposalTitleFrom.
  ///
  /// In fr, this message translates to:
  /// **'Retour du {day}'**
  String proposalTitleFrom(String day);

  /// No description provided for @proposalTime.
  ///
  /// In fr, this message translates to:
  /// **'Horaire : {time}'**
  String proposalTime(String time);

  /// No description provided for @proposalDriverIntro.
  ///
  /// In fr, this message translates to:
  /// **'Tu montes avec'**
  String get proposalDriverIntro;

  /// No description provided for @proposalPassengersIntro.
  ///
  /// In fr, this message translates to:
  /// **'Tes passagers'**
  String get proposalPassengersIntro;

  /// No description provided for @proposalNoPassengers.
  ///
  /// In fr, this message translates to:
  /// **'Personne pour l\'instant. Tu recevras une notification si quelqu\'un est proposé.'**
  String get proposalNoPassengers;

  /// No description provided for @personDetails.
  ///
  /// In fr, this message translates to:
  /// **'Fiabilité {score} sur 5 · détour {minutes} min'**
  String personDetails(String score, int minutes);

  /// No description provided for @privacyNote.
  ///
  /// In fr, this message translates to:
  /// **'Nom et adresse exacte s\'affichent seulement une fois le trajet confirmé à deux.'**
  String get privacyNote;

  /// No description provided for @accept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get decline;

  /// No description provided for @seeOthers.
  ///
  /// In fr, this message translates to:
  /// **'Voir d\'autres voitures'**
  String get seeOthers;

  /// No description provided for @proposalConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Trajet confirmé'**
  String get proposalConfirmed;

  /// No description provided for @proposalWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Tu as accepté. On attend la réponse de l\'autre.'**
  String get proposalWaiting;

  /// No description provided for @proposalDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Proposition refusée.'**
  String get proposalDeclined;

  /// No description provided for @alternativesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Autres voitures'**
  String get alternativesTitle;

  /// No description provided for @alternativesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre voiture compatible pour ce créneau.'**
  String get alternativesEmpty;

  /// No description provided for @choose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get choose;

  /// No description provided for @joined.
  ///
  /// In fr, this message translates to:
  /// **'C\'est noté : tu as choisi cette voiture.'**
  String get joined;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chercher un trajet'**
  String get searchTitle;

  /// No description provided for @searchDayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get searchDayLabel;

  /// No description provided for @searchTimeOptional.
  ///
  /// In fr, this message translates to:
  /// **'Heure (facultatif)'**
  String get searchTimeOptional;

  /// No description provided for @searchNoTime.
  ///
  /// In fr, this message translates to:
  /// **'Selon mon emploi du temps'**
  String get searchNoTime;

  /// No description provided for @searchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune voiture trouvée pour ce créneau.'**
  String get searchEmpty;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un jour et un sens, puis lance la recherche.'**
  String get searchHint;

  /// No description provided for @seatsLeftLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 place} other{{count} places}}'**
  String seatsLeftLabel(int count);

  /// No description provided for @profileSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Emploi du temps'**
  String get profileSchedule;

  /// No description provided for @scheduleConnected.
  ///
  /// In fr, this message translates to:
  /// **'Agenda connecté, mis à jour le {date}.'**
  String scheduleConnected(String date);

  /// No description provided for @scheduleSyncError.
  ///
  /// In fr, this message translates to:
  /// **'La dernière mise à jour a échoué. Vérifie ton lien.'**
  String get scheduleSyncError;

  /// No description provided for @scheduleManualSummary.
  ///
  /// In fr, this message translates to:
  /// **'Horaires saisis pour {count, plural, =1{1 jour} other{{count} jours}}.'**
  String scheduleManualSummary(int count);

  /// No description provided for @scheduleNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun emploi du temps.'**
  String get scheduleNone;

  /// No description provided for @scheduleSync.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get scheduleSync;

  /// No description provided for @scheduleDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter l\'agenda'**
  String get scheduleDisconnect;

  /// No description provided for @scheduleSynced.
  ///
  /// In fr, this message translates to:
  /// **'Emploi du temps mis à jour.'**
  String get scheduleSynced;

  /// No description provided for @rideMapOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir la carte'**
  String get rideMapOpen;

  /// No description provided for @rideMapLabel.
  ///
  /// In fr, this message translates to:
  /// **'Carte du trajet avec {count, plural, =1{1 arrêt} other{{count} arrêts}}'**
  String rideMapLabel(int count);

  /// No description provided for @rideRouteEstimated.
  ///
  /// In fr, this message translates to:
  /// **'Tracé approximatif : le calcul d\'itinéraire n\'était pas disponible.'**
  String get rideRouteEstimated;

  /// No description provided for @rideStopsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Arrêts'**
  String get rideStopsTitle;

  /// No description provided for @rideStopAround.
  ///
  /// In fr, this message translates to:
  /// **'Vers {time}'**
  String rideStopAround(String time);

  /// No description provided for @rideStopSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt {order} : {name}, {place}, vers {time}'**
  String rideStopSemantic(int order, String name, String place, String time);

  /// No description provided for @rideYou.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get rideYou;

  /// No description provided for @rideMeetingPoint.
  ///
  /// In fr, this message translates to:
  /// **'Point de rendez-vous'**
  String get rideMeetingPoint;

  /// No description provided for @ridePriceYouPay.
  ///
  /// In fr, this message translates to:
  /// **'Tu paies {price}'**
  String ridePriceYouPay(String price);

  /// No description provided for @ridePriceYouReceive.
  ///
  /// In fr, this message translates to:
  /// **'Tu reçois {price}'**
  String ridePriceYouReceive(String price);

  /// No description provided for @ridePriceDetail.
  ///
  /// In fr, this message translates to:
  /// **'Estimation : {total} de carburant partagés entre {persons} personnes, plus {commission} de frais de service par passager. Le prix final est calculé à l\'arrivée.'**
  String ridePriceDetail(String total, int persons, String commission);

  /// No description provided for @ridePriceUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Prix indisponible : le véhicule du conducteur n\'est plus renseigné.'**
  String get ridePriceUnknown;

  /// No description provided for @rideAddPassengers.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des passagers'**
  String get rideAddPassengers;

  /// No description provided for @rideChooseMeetingPoint.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un point de rendez-vous'**
  String get rideChooseMeetingPoint;

  /// No description provided for @rideChangeMeetingPoint.
  ///
  /// In fr, this message translates to:
  /// **'Changer de point de rendez-vous'**
  String get rideChangeMeetingPoint;

  /// No description provided for @meetingPointTitle.
  ///
  /// In fr, this message translates to:
  /// **'Point de rendez-vous'**
  String get meetingPointTitle;

  /// No description provided for @meetingPointIntro.
  ///
  /// In fr, this message translates to:
  /// **'Touche la carte pour placer le point où le conducteur te prendra. Il remplace ton adresse et doit rester près de chez toi.'**
  String get meetingPointIntro;

  /// No description provided for @meetingPointMapLabel.
  ///
  /// In fr, this message translates to:
  /// **'Carte : touche pour placer le point de rendez-vous'**
  String get meetingPointMapLabel;

  /// No description provided for @meetingPointLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du point'**
  String get meetingPointLabel;

  /// No description provided for @meetingPointHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. arrêt de bus Mairie'**
  String get meetingPointHint;

  /// No description provided for @meetingPointSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer ce point'**
  String get meetingPointSave;

  /// No description provided for @meetingPointReset.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à mon adresse'**
  String get meetingPointReset;

  /// No description provided for @meetingPointSaved.
  ///
  /// In fr, this message translates to:
  /// **'Point de rendez-vous enregistré.'**
  String get meetingPointSaved;

  /// No description provided for @meetingPointResetDone.
  ///
  /// In fr, this message translates to:
  /// **'Le conducteur passera à ton adresse.'**
  String get meetingPointResetDone;

  /// No description provided for @suggestionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des passagers'**
  String get suggestionsTitle;

  /// No description provided for @suggestionsIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ces étudiants n\'ont pas encore de trajet à cette heure-là. Chaque place prise fait baisser le prix pour tout le monde.'**
  String get suggestionsIntro;

  /// No description provided for @suggestionsCurrentPrice.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui, chaque passager paie {price}.'**
  String suggestionsCurrentPrice(String price);

  /// No description provided for @suggestionWithin.
  ///
  /// In fr, this message translates to:
  /// **'Dans ton détour'**
  String get suggestionWithin;

  /// No description provided for @suggestionBeyond.
  ///
  /// In fr, this message translates to:
  /// **'Au-delà de ton détour max'**
  String get suggestionBeyond;

  /// No description provided for @suggestionPrice.
  ///
  /// In fr, this message translates to:
  /// **'Avec cette personne : {price} par passager'**
  String suggestionPrice(String price);

  /// No description provided for @suggestionInvite.
  ///
  /// In fr, this message translates to:
  /// **'Proposer une place'**
  String get suggestionInvite;

  /// No description provided for @suggestionInvited.
  ///
  /// In fr, this message translates to:
  /// **'Proposition envoyée à {name}.'**
  String suggestionInvited(String name);

  /// No description provided for @suggestionsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Personne d\'autre ne cherche de trajet à cette heure-là.'**
  String get suggestionsEmpty;

  /// No description provided for @suggestionsFull.
  ///
  /// In fr, this message translates to:
  /// **'Ta voiture est complète.'**
  String get suggestionsFull;

  /// No description provided for @errorForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as pas accès à ce trajet.'**
  String get errorForbidden;

  /// No description provided for @errorRideNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'est pas encore confirmé.'**
  String get errorRideNotConfirmed;

  /// No description provided for @errorMeetingPointTooFar.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un point plus proche de chez toi.'**
  String get errorMeetingPointTooFar;

  /// No description provided for @errorRideLocked.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet ne peut plus être modifié.'**
  String get errorRideLocked;

  /// No description provided for @errorSuggestionUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne n\'est plus disponible.'**
  String get errorSuggestionUnavailable;

  /// No description provided for @errorAcceptFirst.
  ///
  /// In fr, this message translates to:
  /// **'Accepte d\'abord ce trajet.'**
  String get errorAcceptFirst;

  /// No description provided for @ridePricePayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tu paies'**
  String get ridePricePayLabel;

  /// No description provided for @ridePriceReceiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tu reçois'**
  String get ridePriceReceiveLabel;

  /// No description provided for @suggestionPriceCompared.
  ///
  /// In fr, this message translates to:
  /// **'Avec cette personne : {price} par passager au lieu de {current}'**
  String suggestionPriceCompared(String price, String current);

  /// No description provided for @rideStopApproximate.
  ///
  /// In fr, this message translates to:
  /// **'Position approximative'**
  String get rideStopApproximate;

  /// No description provided for @rideInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Trajet en cours'**
  String get rideInProgress;

  /// No description provided for @rideCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Trajet terminé'**
  String get rideCompleted;

  /// No description provided for @liveDriverEta.
  ///
  /// In fr, this message translates to:
  /// **'Le conducteur arrive vers {time}'**
  String liveDriverEta(String time);

  /// No description provided for @liveLastKnown.
  ///
  /// In fr, this message translates to:
  /// **'Dernière position connue à {time}'**
  String liveLastKnown(String time);

  /// No description provided for @liveWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de la position du conducteur.'**
  String get liveWaiting;

  /// No description provided for @liveReconnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au suivi en direct…'**
  String get liveReconnecting;

  /// No description provided for @liveEnded.
  ///
  /// In fr, this message translates to:
  /// **'Le suivi en direct est terminé.'**
  String get liveEnded;

  /// No description provided for @presenceValidated.
  ///
  /// In fr, this message translates to:
  /// **'Présence validée'**
  String get presenceValidated;

  /// No description provided for @presencePaid.
  ///
  /// In fr, this message translates to:
  /// **'Présence validée, trajet payé'**
  String get presencePaid;

  /// No description provided for @presenceUnpaid.
  ///
  /// In fr, this message translates to:
  /// **'Présence validée, paiement en attente : recharge ton portefeuille'**
  String get presenceUnpaid;

  /// No description provided for @confirmPresence.
  ///
  /// In fr, this message translates to:
  /// **'Valider ma présence'**
  String get confirmPresence;

  /// No description provided for @presenceDone.
  ///
  /// In fr, this message translates to:
  /// **'Présence validée. Bon trajet.'**
  String get presenceDone;

  /// No description provided for @shareLocation.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma position'**
  String get shareLocation;

  /// No description provided for @finishRide.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le trajet'**
  String get finishRide;

  /// No description provided for @openDeparture.
  ///
  /// In fr, this message translates to:
  /// **'Écran de départ'**
  String get openDeparture;

  /// No description provided for @departureTitle.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get departureTitle;

  /// No description provided for @departureIntro.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie l\'ordre des arrêts, puis démarre : tes passagers te verront arriver.'**
  String get departureIntro;

  /// No description provided for @startRide.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer le trajet'**
  String get startRide;

  /// No description provided for @launchNavigation.
  ///
  /// In fr, this message translates to:
  /// **'Lancer la navigation'**
  String get launchNavigation;

  /// No description provided for @nextStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt suivant'**
  String get nextStop;

  /// No description provided for @changeNavApp.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'application GPS'**
  String get changeNavApp;

  /// No description provided for @navAppChoose.
  ///
  /// In fr, this message translates to:
  /// **'Avec quelle application ?'**
  String get navAppChoose;

  /// No description provided for @navAppGoogleMaps.
  ///
  /// In fr, this message translates to:
  /// **'Google Maps'**
  String get navAppGoogleMaps;

  /// No description provided for @navAppWaze.
  ///
  /// In fr, this message translates to:
  /// **'Waze'**
  String get navAppWaze;

  /// No description provided for @navAppAppleMaps.
  ///
  /// In fr, this message translates to:
  /// **'Plans'**
  String get navAppAppleMaps;

  /// No description provided for @navAppNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune application GPS trouvée sur ce téléphone.'**
  String get navAppNone;

  /// No description provided for @navOpenFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir l\'application GPS.'**
  String get navOpenFailed;

  /// No description provided for @wazeStopByStop.
  ///
  /// In fr, this message translates to:
  /// **'Waze ne prend qu\'une destination : tu iras d\'arrêt en arrêt.'**
  String get wazeStopByStop;

  /// No description provided for @pickedUp.
  ///
  /// In fr, this message translates to:
  /// **'Monté'**
  String get pickedUp;

  /// No description provided for @markPickedUp.
  ///
  /// In fr, this message translates to:
  /// **'Monté à bord'**
  String get markPickedUp;

  /// No description provided for @pickedUpSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Marquer {name} comme monté à bord'**
  String pickedUpSemantic(String name);

  /// No description provided for @destination.
  ///
  /// In fr, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @locationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partage ta position pendant le trajet'**
  String get locationTitle;

  /// No description provided for @locationBody.
  ///
  /// In fr, this message translates to:
  /// **'Les participants de ce trajet voient où tu es, seulement pendant le trajet. Le partage s\'arrête à l\'arrivée. Ta position valide aussi ta présence, ce qui déclenche le paiement.'**
  String get locationBody;

  /// No description provided for @locationBackground.
  ///
  /// In fr, this message translates to:
  /// **'Pour que le suivi continue écran éteint, une notification reste affichée pendant le trajet.'**
  String get locationBackground;

  /// No description provided for @locationAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser la position'**
  String get locationAllow;

  /// No description provided for @locationLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get locationLater;

  /// No description provided for @locationDenied.
  ///
  /// In fr, this message translates to:
  /// **'Sans ta position, le suivi et la validation de présence ne marchent pas. Active-la pour Uni-Moov dans les réglages du téléphone.'**
  String get locationDenied;

  /// No description provided for @locationOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get locationOpenSettings;

  /// No description provided for @locationNotificationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trajet Uni-Moov en cours'**
  String get locationNotificationTitle;

  /// No description provided for @locationNotificationText.
  ///
  /// In fr, this message translates to:
  /// **'Ta position est partagée avec ton trajet jusqu\'à l\'arrivée.'**
  String get locationNotificationText;

  /// No description provided for @profileWallet.
  ///
  /// In fr, this message translates to:
  /// **'Portefeuille'**
  String get profileWallet;

  /// No description provided for @walletTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton portefeuille'**
  String get walletTitle;

  /// No description provided for @walletIntro.
  ///
  /// In fr, this message translates to:
  /// **'Tes trajets sont payés depuis ce solde, sans frais à chaque trajet.'**
  String get walletIntro;

  /// No description provided for @walletBalance.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get walletBalance;

  /// No description provided for @walletHeld.
  ///
  /// In fr, this message translates to:
  /// **'{amount} retenus pour un trajet en cours'**
  String walletHeld(String amount);

  /// No description provided for @walletTopup.
  ///
  /// In fr, this message translates to:
  /// **'Recharger {amount}'**
  String walletTopup(String amount);

  /// No description provided for @walletTopupDone.
  ///
  /// In fr, this message translates to:
  /// **'Portefeuille rechargé.'**
  String get walletTopupDone;

  /// No description provided for @walletHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get walletHistory;

  /// No description provided for @walletEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération pour l\'instant.'**
  String get walletEmpty;

  /// No description provided for @walletKindTopup.
  ///
  /// In fr, this message translates to:
  /// **'Recharge'**
  String get walletKindTopup;

  /// No description provided for @walletKindRideCharge.
  ///
  /// In fr, this message translates to:
  /// **'Trajet payé'**
  String get walletKindRideCharge;

  /// No description provided for @walletKindRideCredit.
  ///
  /// In fr, this message translates to:
  /// **'Trajet reçu'**
  String get walletKindRideCredit;

  /// No description provided for @walletKindPayout.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get walletKindPayout;

  /// No description provided for @walletKindRefund.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get walletKindRefund;

  /// No description provided for @walletFake.
  ///
  /// In fr, this message translates to:
  /// **'Mode test : aucun argent réel n\'est prélevé.'**
  String get walletFake;

  /// No description provided for @errorTooEarly.
  ///
  /// In fr, this message translates to:
  /// **'Trop tôt pour démarrer ce trajet.'**
  String get errorTooEarly;

  /// No description provided for @errorRideNotStarted.
  ///
  /// In fr, this message translates to:
  /// **'Le trajet n\'a pas encore commencé.'**
  String get errorRideNotStarted;

  /// No description provided for @errorPresenceNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Ton téléphone et celui du conducteur doivent être proches.'**
  String get errorPresenceNotConfirmed;

  /// No description provided for @errorTopupTooSmall.
  ///
  /// In fr, this message translates to:
  /// **'Montant de recharge trop faible.'**
  String get errorTopupTooSmall;

  /// No description provided for @errorTopupFailed.
  ///
  /// In fr, this message translates to:
  /// **'La recharge a été refusée.'**
  String get errorTopupFailed;

  /// No description provided for @finishConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le trajet ?'**
  String get finishConfirmTitle;

  /// No description provided for @finishConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Le suivi s\'arrête pour tout le monde et les passagers dont la présence n\'est pas validée sont comptés absents.'**
  String get finishConfirmBody;

  /// No description provided for @finishConfirmCancel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer le trajet'**
  String get finishConfirmCancel;

  /// No description provided for @cancelMyPlace.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ma place'**
  String get cancelMyPlace;

  /// No description provided for @cancelRide.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le trajet'**
  String get cancelRide;

  /// No description provided for @cancelSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce trajet ?'**
  String get cancelSheetTitle;

  /// No description provided for @cancelTierEarly.
  ///
  /// In fr, this message translates to:
  /// **'Tu préviens tôt : ton score baisse un peu.'**
  String get cancelTierEarly;

  /// No description provided for @cancelTierMedium.
  ///
  /// In fr, this message translates to:
  /// **'Le départ approche : ton score baisse davantage.'**
  String get cancelTierMedium;

  /// No description provided for @cancelTierLate.
  ///
  /// In fr, this message translates to:
  /// **'Départ imminent : ton score baisse nettement.'**
  String get cancelTierLate;

  /// No description provided for @cancelPassengerEffect.
  ///
  /// In fr, this message translates to:
  /// **'Le conducteur est prévenu et ta place est proposée à quelqu\'un d\'autre.'**
  String get cancelPassengerEffect;

  /// No description provided for @cancelDriverEffect.
  ///
  /// In fr, this message translates to:
  /// **'Tes passagers sont prévenus et on leur cherche une autre voiture.'**
  String get cancelDriverEffect;

  /// No description provided for @cancelKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder mon trajet'**
  String get cancelKeep;

  /// No description provided for @cancelDone.
  ///
  /// In fr, this message translates to:
  /// **'Trajet annulé.'**
  String get cancelDone;

  /// No description provided for @ratingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Noter le trajet'**
  String get ratingTitle;

  /// No description provided for @ratingIntro.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif. Ta note compte dans le score de fiabilité de la personne.'**
  String get ratingIntro;

  /// No description provided for @ratingStar.
  ///
  /// In fr, this message translates to:
  /// **'{stars} sur 5 pour {name}'**
  String ratingStar(int stars, String name);

  /// No description provided for @ratingGiven.
  ///
  /// In fr, this message translates to:
  /// **'Ta note : {stars} sur 5'**
  String ratingGiven(int stars);

  /// No description provided for @ratingDone.
  ///
  /// In fr, this message translates to:
  /// **'Note enregistrée.'**
  String get ratingDone;

  /// No description provided for @ratingClosed.
  ///
  /// In fr, this message translates to:
  /// **'La notation de ce trajet est fermée.'**
  String get ratingClosed;

  /// No description provided for @ratingDriver.
  ///
  /// In fr, this message translates to:
  /// **'Conducteur'**
  String get ratingDriver;

  /// No description provided for @ratingPassenger.
  ///
  /// In fr, this message translates to:
  /// **'Passager'**
  String get ratingPassenger;

  /// No description provided for @profileReliability.
  ///
  /// In fr, this message translates to:
  /// **'Fiabilité'**
  String get profileReliability;

  /// No description provided for @profileReliabilityBody.
  ///
  /// In fr, this message translates to:
  /// **'Ton score, ce qui le compose, et les pénalités que tu peux contester.'**
  String get profileReliabilityBody;

  /// No description provided for @reliabilityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ma fiabilité'**
  String get reliabilityTitle;

  /// No description provided for @reliabilityIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ton score aide à composer des trajets fiables, il ne t\'exclut jamais. Il se calcule sur les {days} derniers jours.'**
  String reliabilityIntro(int days);

  /// No description provided for @reliabilityScore.
  ///
  /// In fr, this message translates to:
  /// **'{score} sur 5'**
  String reliabilityScore(String score);

  /// No description provided for @reliabilityScoreLabel.
  ///
  /// In fr, this message translates to:
  /// **'Score de fiabilité'**
  String get reliabilityScoreLabel;

  /// No description provided for @reliabilityCompleted.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun trajet mené à bien} =1{1 trajet mené à bien} other{{count} trajets menés à bien}}'**
  String reliabilityCompleted(int count);

  /// No description provided for @reliabilityCancellations.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune annulation} =1{1 annulation} other{{count} annulations}}'**
  String reliabilityCancellations(int count);

  /// No description provided for @reliabilityNoShows.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune absence} =1{1 absence} other{{count} absences}}'**
  String reliabilityNoShows(int count);

  /// No description provided for @reliabilityRatings.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 note, {average} sur 5} other{{count} notes, moyenne {average} sur 5}}'**
  String reliabilityRatings(int count, String average);

  /// No description provided for @reliabilityNoRatings.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de note'**
  String get reliabilityNoRatings;

  /// No description provided for @reliabilityEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui a compté dans ton score'**
  String get reliabilityEventsTitle;

  /// No description provided for @reliabilityEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune annulation ni absence sur les {days} derniers jours.'**
  String reliabilityEmpty(int days);

  /// No description provided for @eventCancelEarly.
  ///
  /// In fr, this message translates to:
  /// **'Annulation prévenue tôt'**
  String get eventCancelEarly;

  /// No description provided for @eventCancelMedium.
  ///
  /// In fr, this message translates to:
  /// **'Annulation peu avant le départ'**
  String get eventCancelMedium;

  /// No description provided for @eventCancelLate.
  ///
  /// In fr, this message translates to:
  /// **'Annulation au dernier moment'**
  String get eventCancelLate;

  /// No description provided for @eventNoShow.
  ///
  /// In fr, this message translates to:
  /// **'Absence au rendez-vous'**
  String get eventNoShow;

  /// No description provided for @eventCorrection.
  ///
  /// In fr, this message translates to:
  /// **'Pénalité corrigée après vérification'**
  String get eventCorrection;

  /// No description provided for @eventRideOn.
  ///
  /// In fr, this message translates to:
  /// **'Trajet du {day}'**
  String eventRideOn(String day);

  /// No description provided for @contest.
  ///
  /// In fr, this message translates to:
  /// **'Contester'**
  String get contest;

  /// No description provided for @rideProblem.
  ///
  /// In fr, this message translates to:
  /// **'Un problème sur ce trajet ?'**
  String get rideProblem;

  /// No description provided for @rideAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Ta présence n\'a pas été validée : ce trajet compte comme une absence.'**
  String get rideAbsent;

  /// No description provided for @disputeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un problème sur ce trajet ?'**
  String get disputeTitle;

  /// No description provided for @disputeIntro.
  ///
  /// In fr, this message translates to:
  /// **'On vérifie d\'abord ce que l\'app a enregistré : heure d\'annulation, présence au rendez-vous. Si ça ne suffit pas, l\'équipe Uni-Moov te répond par mail.'**
  String get disputeIntro;

  /// No description provided for @disputeReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get disputeReasonLabel;

  /// No description provided for @disputeReasonCancellation.
  ///
  /// In fr, this message translates to:
  /// **'Je conteste la pénalité d\'annulation'**
  String get disputeReasonCancellation;

  /// No description provided for @disputeReasonAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Mon absence est une erreur'**
  String get disputeReasonAbsent;

  /// No description provided for @disputeReasonPayment.
  ///
  /// In fr, this message translates to:
  /// **'Un souci de paiement'**
  String get disputeReasonPayment;

  /// No description provided for @disputeReasonDriver.
  ///
  /// In fr, this message translates to:
  /// **'Un souci avec le conducteur'**
  String get disputeReasonDriver;

  /// No description provided for @disputeReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre chose'**
  String get disputeReasonOther;

  /// No description provided for @disputeMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Explique en quelques mots (facultatif)'**
  String get disputeMessageLabel;

  /// No description provided for @disputeSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get disputeSend;

  /// No description provided for @disputeYours.
  ///
  /// In fr, this message translates to:
  /// **'Tes demandes sur ce trajet'**
  String get disputeYours;

  /// No description provided for @disputeWithTeam.
  ///
  /// In fr, this message translates to:
  /// **'Transmis à l\'équipe Uni-Moov, réponse par mail.'**
  String get disputeWithTeam;

  /// No description provided for @disputeEscalate.
  ///
  /// In fr, this message translates to:
  /// **'Je ne suis pas d\'accord'**
  String get disputeEscalate;

  /// No description provided for @disputeEscalated.
  ///
  /// In fr, this message translates to:
  /// **'Demande transmise à l\'équipe.'**
  String get disputeEscalated;

  /// No description provided for @disputeUpheld.
  ///
  /// In fr, this message translates to:
  /// **'Décision maintenue'**
  String get disputeUpheld;

  /// No description provided for @disputeCorrected.
  ///
  /// In fr, this message translates to:
  /// **'Corrigé'**
  String get disputeCorrected;

  /// No description provided for @disputePending.
  ///
  /// In fr, this message translates to:
  /// **'En cours d\'examen'**
  String get disputePending;

  /// No description provided for @explainPenaltyMatches.
  ///
  /// In fr, this message translates to:
  /// **'Les horodatages confirment l\'heure de ton annulation : la pénalité est maintenue.'**
  String get explainPenaltyMatches;

  /// No description provided for @explainPenaltyRecomputed.
  ///
  /// In fr, this message translates to:
  /// **'La pénalité ne correspondait pas aux horodatages : elle est corrigée.'**
  String get explainPenaltyRecomputed;

  /// No description provided for @explainNoPenalty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pénalité n\'a été appliquée pour ce trajet.'**
  String get explainNoPenalty;

  /// No description provided for @explainPresenceValidated.
  ///
  /// In fr, this message translates to:
  /// **'Ta présence avait bien été validée : la pénalité est retirée.'**
  String get explainPresenceValidated;

  /// No description provided for @explainDriverConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Le conducteur t\'a déclaré à bord sans validation par GPS : l\'équipe va trancher.'**
  String get explainDriverConfirmed;

  /// No description provided for @explainNoPresence.
  ///
  /// In fr, this message translates to:
  /// **'Aucune validation de présence n\'a été enregistrée : l\'absence est maintenue.'**
  String get explainNoPresence;

  /// No description provided for @explainNotAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Aucune absence n\'est enregistrée pour toi sur ce trajet.'**
  String get explainNotAbsent;

  /// No description provided for @explainNeedsHuman.
  ///
  /// In fr, this message translates to:
  /// **'L\'équipe Uni-Moov examine ta demande et te répond par mail.'**
  String get explainNeedsHuman;

  /// No description provided for @reportAction.
  ///
  /// In fr, this message translates to:
  /// **'Signaler une personne'**
  String get reportAction;

  /// No description provided for @reportIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ton signalement reste confidentiel : seule l\'équipe Uni-Moov le lit et peut te recontacter par mail.'**
  String get reportIntro;

  /// No description provided for @reportWho.
  ///
  /// In fr, this message translates to:
  /// **'Qui ?'**
  String get reportWho;

  /// No description provided for @reportWhy.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi ?'**
  String get reportWhy;

  /// No description provided for @reportDangerous.
  ///
  /// In fr, this message translates to:
  /// **'Conduite dangereuse'**
  String get reportDangerous;

  /// No description provided for @reportInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Comportement déplacé'**
  String get reportInappropriate;

  /// No description provided for @reportFake.
  ///
  /// In fr, this message translates to:
  /// **'Faux profil'**
  String get reportFake;

  /// No description provided for @reportOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre chose'**
  String get reportOther;

  /// No description provided for @reportSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get reportSend;

  /// No description provided for @reportDone.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé.'**
  String get reportDone;

  /// No description provided for @errorNotAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'as pas accepté ce trajet.'**
  String get errorNotAccepted;

  /// No description provided for @errorAlreadyRated.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà noté cette personne.'**
  String get errorAlreadyRated;

  /// No description provided for @errorNotRateable.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne peux pas noter cette personne pour ce trajet.'**
  String get errorNotRateable;

  /// No description provided for @errorRatingClosed.
  ///
  /// In fr, this message translates to:
  /// **'La notation de ce trajet est fermée.'**
  String get errorRatingClosed;

  /// No description provided for @errorRideNotCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'est pas terminé.'**
  String get errorRideNotCompleted;

  /// No description provided for @errorDisputeExists.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà signalé ce problème pour ce trajet.'**
  String get errorDisputeExists;

  /// No description provided for @errorDisputeClosed.
  ///
  /// In fr, this message translates to:
  /// **'Le délai pour signaler un problème sur ce trajet est passé.'**
  String get errorDisputeClosed;

  /// No description provided for @errorDisputeNotApplicable.
  ///
  /// In fr, this message translates to:
  /// **'Ce motif ne correspond pas à ce trajet.'**
  String get errorDisputeNotApplicable;

  /// No description provided for @errorReportLimit.
  ///
  /// In fr, this message translates to:
  /// **'Tu as atteint le nombre de signalements du jour.'**
  String get errorReportLimit;

  /// No description provided for @ratingSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ma note ({stars} sur 5)'**
  String ratingSend(int stars);

  /// No description provided for @cancelSheetTitlePassenger.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ta place ?'**
  String get cancelSheetTitlePassenger;

  /// No description provided for @cancelDonePassenger.
  ///
  /// In fr, this message translates to:
  /// **'Ta place est annulée.'**
  String get cancelDonePassenger;

  /// No description provided for @eventContestClosed.
  ///
  /// In fr, this message translates to:
  /// **'Délai de contestation dépassé.'**
  String get eventContestClosed;

  /// No description provided for @disputeWhy.
  ///
  /// In fr, this message translates to:
  /// **'Dis-nous pourquoi (facultatif)'**
  String get disputeWhy;

  /// No description provided for @disputeSendTeam.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer à l\'équipe'**
  String get disputeSendTeam;

  /// No description provided for @disputeAnother.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un autre problème'**
  String get disputeAnother;

  /// No description provided for @disputeChooseReason.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un motif pour continuer.'**
  String get disputeChooseReason;

  /// No description provided for @reportEmergency.
  ///
  /// In fr, this message translates to:
  /// **'En cas de danger immédiat, appelle le 112.'**
  String get reportEmergency;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
