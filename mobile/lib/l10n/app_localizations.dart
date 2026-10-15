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

  /// No description provided for @calendarBody.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt, Uni-Moov lira ton emploi du temps pour te proposer tes trajets de la semaine. Tu le connecteras depuis ton profil.'**
  String get calendarBody;

  /// No description provided for @calendarAction.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get calendarAction;

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

  /// No description provided for @weekEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Tes propositions de trajets arriveront ici une fois ton emploi du temps connecté.'**
  String get weekEmpty;

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
