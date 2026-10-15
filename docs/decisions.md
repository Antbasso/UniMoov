# Journal des décisions

Une ligne par décision : `date | décision | raison`.

2026-10-15 | Cartes : flutter_map + PMTiles OSM hébergé en statique | gratuit, sans quota ni clé
2026-10-15 | Jobs asynchrones avec pg-boss | évite d'ajouter Redis en v1
2026-10-15 | Waze : navigation arrêt par arrêt | Waze n'accepte qu'une seule destination par lien
2026-10-15 | Un seul VPS Docker Compose, pas de service managé | coût de fonctionnement visé 5 à 7 €/mois
2026-10-15 | Géocodage Base Adresse Nationale, itinéraires OpenRouteService gratuit puis OSRM auto-hébergé si besoin | coût nul
2026-10-15 | V1.1 : connexion Google/Apple, agenda Google/Microsoft, pièces jointes | réduit coût et temps de dev
2026-10-15 | Paiement dans l'app via portefeuille prépayé (recharge min. 10 €, retrait groupé) chez un prestataire agréé, fournisseur factice d'abord | dilue les frais fixes par transaction, UniMoov ne détient pas les fonds. Principe validé par l'équipe le 2026-10-15 ; reste à décider : choix du prestataire, montants (commission, recharge min., seuil de retrait)
2026-10-15 | M0 : TypeScript 6.0 (pas 7) | typescript-eslint ne supporte pas encore TypeScript 7
2026-10-15 | M0 : migrations SQL écrites à la main, exécutées par le migrateur de drizzle-orm ; pas de drizzle-kit (script `db:new-migration` maison) | drizzle-kit embarque une version vulnérable d'esbuild ; le schéma de référence est déjà en SQL
2026-10-15 | M0 : la migration 0000 reprend `docs/data-model.sql` à l'identique ; Drizzle TS ne décrit que les tables utilisées par le code | une seule source du schéma physique, pas de double maintenance
2026-10-15 | M0 : valeurs par défaut de `app_settings` en migration (0001), pas dans le seed : commission 20 c/passager, carburant 1,80 €/L, recharge min. 10 €, marge de retenue 20 %, retrait min. 10 € tous les 7 jours, détour 10 min, 20 recherches/jour, rayon de présence 150 m, traces 7 jours, chat de trajet archivé à 30 j et supprimé à 90 j | la production en a besoin ; ON CONFLICT DO NOTHING préserve les réglages. Commission et rétention du chat restent à valider par l'équipe (cahier §16)
2026-10-15 | M0 : campus pilote (Annecy, USMB) créé par migration avec un identifiant fixe | donnée de référence nécessaire en production
2026-10-15 | M0 : secteur approximatif = cellule de grille de 500 m (`sectorOf`, `src/shared/geo.ts`), identifiant « ligne:colonne » | simple, sans dépendance, calculé côté serveur
2026-10-15 | M0 : journaux de requête réduits à méthode + route (ni IP, ni en-têtes, ni paramètres d'URL) | aucune donnée personnelle dans les logs (RGPD)
2026-10-15 | M0 : tests backend séparés : `npm test` (unitaires, sans base) et `npm run test:integration` (PostGIS via TEST_DATABASE_URL, base effacée à chaque exécution) | tests rapides en local, intégration réelle en CI
2026-10-15 | M0 : `/health` hors préfixe `/api/v1`, répond 503 si la base est injoignable | sonde Docker et supervision (UptimeRobot) sans authentification
2026-10-15 | M0 : OpenAPI (`/docs`) reporté à M1 | aucune route métier en M0 ; @fastify/swagger ajouté avec les premières routes
2026-10-15 | M0 : image Docker Node 24 (LTS) ; Node ≥ 22.12 accepté en local | version LTS active
2026-10-15 | M0 mobile : dépendances limitées à flutter_riverpod, go_router, dio, intl (+ flutter_localizations) ; freezed, json_serializable, flutter_secure_storage, geolocator, firebase_messaging, flutter_map ajoutés au jalon qui les utilise | pas de dépendance sans usage
2026-10-15 | M0 mobile : thème généré par `tool/generate_tokens.dart` (Dart pur, sans build_runner), vérifié en CI | tokens.json reste la seule source
2026-10-15 | M0 mobile : UniMoov Display convertie de WOFF2 en TTF (fontTools, sans modification des glyphes) ; Poppins et Caveat embarquées en TTF (OFL, paquets @expo-google-fonts) plutôt que google_fonts | Flutter ne charge pas le WOFF2 ; pas d'appel réseau à Google à l'exécution (vie privée, hors ligne)
2026-10-15 | M0 mobile : icônes Material arrondies/au trait en attendant un jeu d'icônes au trait 2,5 px | le design system n'en fournit pas encore ; à remplacer sans changer les composants
2026-10-15 | M0 mobile : logo (fond blanc opaque) posé sur une plaque `surface-raised` claire dans les deux thèmes | logo.md interdit de le poser directement sur fond sombre ; seul `assets/logo.png` existe (pas d'icône transparente)
2026-10-15 | M0 mobile : pas de réessai automatique Riverpod pour l'état de l'API ; bouton « Réessayer » | l'état d'erreur doit rester visible
2026-10-15 | M0 mobile : URL de l'API par `--dart-define=API_BASE_URL` (défaut http://10.0.2.2:3000) ; HTTP en clair autorisé seulement dans le manifeste Android de debug | pas de secret dans l'app, HTTPS en production
2026-10-15 | M0 : goldens de l'accueil (clair, sombre) générés avec Flutter 3.47.7, version figée en CI | rendu reproductible
