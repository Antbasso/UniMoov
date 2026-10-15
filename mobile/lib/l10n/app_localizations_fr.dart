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
  String get homeTitle => 'Ton emploi du temps organise aussi tes trajets.';

  @override
  String get homeSubtitle => 'Covoiturage domicile-campus pour les étudiants d\'Annecy';

  @override
  String get homeNote => 'Bientôt sur ton campus !';

  @override
  String get homeBenefitSchedule => 'Trajets calés sur tes cours';

  @override
  String get homeBenefitPrice => 'Frais partagés au juste prix';

  @override
  String get homeBenefitConfirm => 'Rien sans votre accord à deux';

  @override
  String get homeStart => 'Commencer';

  @override
  String get homeStartSoon => 'L\'inscription arrive très vite.';

  @override
  String get apiStatusLoading => 'Connexion au serveur…';

  @override
  String get apiStatusOk => 'Serveur connecté';

  @override
  String get apiStatusDegraded => 'Serveur dégradé';

  @override
  String get apiStatusError => 'Serveur injoignable';

  @override
  String get retry => 'Réessayer';

  @override
  String get fieldErrorPrefix => 'Erreur';

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
}
