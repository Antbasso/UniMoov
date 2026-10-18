import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/appearance.dart';
import 'core/theme/um_theme.dart';
import 'features/demo/demo_mode.dart';
import 'l10n/app_localizations.dart';

class UniMoovApp extends ConsumerWidget {
  const UniMoovApp({super.key, this.themeMode});

  /// Imposé (tests, captures) ; sinon le choix fait dans le profil.
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildUmTheme(Brightness.light),
      darkTheme: buildUmTheme(Brightness.dark),
      themeMode: themeMode ?? appearance.themeMode,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
      // Démo : bandeau permanent, pour ne jamais confondre avec de vraies données.
      builder: (context, child) {
        // Animations réduites dans le profil : comme le réglage d'accessibilité du téléphone.
        var content = appearance.reduceMotion
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : child!;
        if (ref.watch(demoActiveProvider)) {
          content = Banner(
            message: AppLocalizations.of(context).demoBanner,
            location: BannerLocation.topEnd,
            color: context.umColors.brandStrong,
            child: content,
          );
        }
        return content;
      },
    );
  }
}
