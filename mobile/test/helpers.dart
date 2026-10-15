import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:unimoov/core/theme/um_theme.dart';
import 'package:unimoov/l10n/app_localizations.dart';

/// Enveloppe un widget avec le thème Uni-Moov et la localisation française.
Widget wrap(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
  theme: buildUmTheme(brightness),
  locale: const Locale('fr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: Center(child: child)),
);
