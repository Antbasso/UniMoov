# Application mobile Uni-Moov (Flutter)

Android et iOS uniquement. Architecture feature-first : `lib/features/<feature>/{data,domain,presentation}`,
socle commun dans `lib/core/` (thème, composants `Um*`, routage, client API).

## Commandes

```bash
flutter pub get
flutter analyze
flutter test                                  # unitaires, widgets et goldens (clair/sombre)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # émulateur Android, API locale
dart run tool/generate_tokens.dart            # régénère le thème depuis docs/design-system/tokens.json
flutter gen-l10n                              # régénère les textes depuis lib/l10n/app_fr.arb
flutter test --update-goldens                 # après un changement visuel voulu
```

## Repères

- Thème : `lib/core/theme/tokens.g.dart` est **généré** (ne pas modifier à la main), `um_theme.dart` construit le `ThemeData` et l'extension `context.umColors`.
- Polices : `assets/fonts/` (UniMoov Display convertie du WOFF2 du design system, Poppins et Caveat sous licence OFL, fichiers de licence à côté).
- Textes : tous dans `lib/l10n/app_fr.arb` (tutoiement, casse de phrase, « Uni-Moov », une exclamation par écran).
- Pas de couleur, taille ni rayon codé en dur dans les widgets : uniquement les tokens.
