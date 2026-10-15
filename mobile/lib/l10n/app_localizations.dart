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

  /// No description provided for @homeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton emploi du temps organise aussi tes trajets.'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Covoiturage domicile-campus pour les étudiants d\'Annecy'**
  String get homeSubtitle;

  /// No description provided for @homeNote.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt sur ton campus !'**
  String get homeNote;

  /// No description provided for @homeBenefitSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Trajets calés sur tes cours'**
  String get homeBenefitSchedule;

  /// No description provided for @homeBenefitPrice.
  ///
  /// In fr, this message translates to:
  /// **'Frais partagés au juste prix'**
  String get homeBenefitPrice;

  /// No description provided for @homeBenefitConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmé à deux, toujours'**
  String get homeBenefitConfirm;

  /// No description provided for @homeStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get homeStart;

  /// No description provided for @homeStartSoon.
  ///
  /// In fr, this message translates to:
  /// **'L\'inscription arrive très vite.'**
  String get homeStartSoon;

  /// No description provided for @apiStatusLoading.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours…'**
  String get apiStatusLoading;

  /// No description provided for @apiStatusOk.
  ///
  /// In fr, this message translates to:
  /// **'Connexion établie'**
  String get apiStatusOk;

  /// No description provided for @apiStatusDegraded.
  ///
  /// In fr, this message translates to:
  /// **'Service perturbé pour l\'instant'**
  String get apiStatusDegraded;

  /// No description provided for @apiStatusError.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible pour l\'instant'**
  String get apiStatusError;

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
