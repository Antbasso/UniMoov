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
2026-10-15 | Revue M0 : les erreurs client de Fastify (JSON mal formé, type de contenu, corps trop gros) répondent 4xx au format standard au lieu de 500 | une requête invalide n'est pas une erreur serveur
2026-10-15 | Revue M0 : écouteur d'erreur sur le pool PostgreSQL, journalisé par l'API | une coupure de base ne doit pas arrêter le processus
2026-10-15 | Revue M0 : la base de test est créée automatiquement et doit finir par `_test`, sinon les tests refusent de s'exécuter | évite d'effacer une base de dev par erreur
2026-10-15 | Revue M0 : `TRUST_PROXY` (faux par défaut) pour lire l'IP réelle derrière Caddy | nécessaire à la limite de débit de M1 ; l'IP ne va jamais dans les journaux
2026-10-15 | Revue M0 : iOS autorise seulement le réseau local en HTTP (`NSAllowsLocalNetworking`) | API de dev joignable depuis le simulateur, HTTPS partout ailleurs
2026-10-15 | Revue M0 : dimensions de composants (48 px, anneau 3 px, icônes 16/24/48…) centralisées dans `UmSize`, textes de bouton en `body` 600 (16 px), les 15 styles Material reliés à l'échelle | aucune taille en dur dans les widgets, aucun style hors échelle
2026-10-15 | Revue M0 : anneau de focus dessiné hors du bouton (décalé de 2 px, comme l'outline CSS) ; aide et erreur des champs rattachées au champ pour les lecteurs d'écran | conformité au design system et accessibilité
2026-10-15 | Revue M0 : textes revus (« Confirmé à deux, toujours », « Connexion impossible pour l'instant ») | tutoiement et pas de jargon technique
2026-10-15 | Revue M0 : goldens comparés avec une tolérance de 0,5 % des pixels | écarts d'anticrénelage entre machines ; un vrai changement visuel dépasse largement ce seuil
2026-10-15 | Revue M0 : corrections d'erreurs évidentes dans docs/design-system (chemin `components.css`, logo `assets/logo.png`, icône seule à fournir, usage du style `label` aligné sur `components.css`) | la documentation citait des fichiers absents et se contredisait
2026-10-15 | M1 : code d'inscription à 6 chiffres, 10 min, usage unique, 5 essais, 1 min entre deux envois, stocké en HMAC lié à l'adresse | cahier §1 et AGENTS « Sécurité » ; un code volé en base ne sert pas ailleurs
2026-10-15 | M1 : demande de code avec réponse identique si le compte existe (mail « tu as déjà un compte » à la place du code) ; connexion à coût constant pour un compte inconnu | pas d'énumération des comptes
2026-10-15 | M1 : domaines autorisés dans `app_settings.auth.allowedEmailDomains` (`univ-smb.fr`, `etu.univ-smb.fr` et sous-domaines) | réglable sans déploiement pour un nouveau campus
2026-10-15 | M1 : mots de passe argon2id via @node-rs/argon2 (binaires précompilés, musl inclus), 8 à 128 caractères | AGENTS impose argon2 ; pas de chaîne de compilation dans l'image Docker
2026-10-15 | M1 : JWT HS256 15 min (@fastify/jwt), refresh opaque 30 jours stocké haché, rotation à chaque usage, réutilisation = révocation de toute la session | architecture §9 ; détection de vol de jeton
2026-10-15 | M1 : pas de délai de grâce sur la réutilisation d'un refresh token | sécurité d'abord ; à revoir si des déconnexions intempestives apparaissent sur réseau instable (réponse perdue puis rejeu)
2026-10-15 | M1 : limites de débit en mémoire (@fastify/rate-limit, pas de Redis) par IP : code 5/15 min, vérification et connexion 10/15 min, refresh/logout 30/min | AGENTS « Limite de débit » ; un seul processus API sur le VPS
2026-10-15 | M1 : le garde JWT vérifie à chaque requête que le compte existe et n'est pas supprimé (une requête par clé primaire) | un jeton valide ne survit pas à la suppression du compte
2026-10-15 | M1 : MailProvider « console » en développement (adresse masquée dans le journal), refusé en production par la config ; vrai fournisseur (palier gratuit) à choisir par l'équipe avant le pilote | aucun service payant sans validation (docs/couts.md)
2026-10-15 | M1 : géocodage par la Géoplateforme (`data.geopf.fr/geocodage`, successeur de api-adresse.data.gouv.fr), score minimal 0,5, cache mémoire LRU 500 entrées / 24 h, rien en base | gratuit, sans clé ; les adresses sont des données personnelles
2026-10-15 | M1 : compte rattaché au campus pilote à l'inscription (premier campus) ; choix du campus quand un second site existera | un seul campus dans le pilote
2026-10-15 | M1 : onboarding en 4 étapes (adresse, véhicule, rôle, emploi du temps) stockées dans `users.onboarding_steps` ; l'étape « emploi du temps » est notée passée en attendant M2 | reprise exacte après fermeture de l'app
2026-10-15 | M1 : mode découverte tant que l'adresse ou le campus manque, même si les étapes ont été passées | le matching (M2) en a besoin
2026-10-15 | M1 : pause « une semaine sur N » (N de 2 à 4) comptée en semaines civiles depuis la semaine de début, dates au fuseau de Paris, un an maximum, 20 pauses maximum | cahier §12 (alternance) ; règle simple et testée
2026-10-15 | M1 : un seul véhicule par utilisateur ; le retirer repasse en « toujours passager » | cahier §2
2026-10-15 | M1 : OpenAPI sur `/docs` uniquement si NODE_ENV=development ; Compose démarre en développement par défaut, la production doit fixer NODE_ENV=production dans `.env` | pas de documentation publique ni de mail console en production
2026-10-15 | M1 mobile : pas de freezed/json_serializable pour l'instant (une dizaine de modèles écrits à la main et testés) | pas de génération de code tant qu'elle ne fait pas gagner de temps (docs/couts.md) ; contredit la stack d'AGENTS.md, à revoir en M2 si les modèles se multiplient
2026-10-15 | M1 mobile : jetons dans flutter_secure_storage ; intercepteur dio qui rafraîchit une seule fois sur 401 (QueuedInterceptor) et ne déconnecte que si le serveur refuse le refresh (pas sur coupure réseau) | évite la réutilisation d'un refresh token par des requêtes simultanées
2026-10-15 | M1 mobile : redirections go_router calculées par une fonction pure, réévaluées seulement quand la session, le chargement du profil ou la fin de l'onboarding changent | une simple modification du profil relançait le routeur et rouvrait la page quittée (bug trouvé par les tests)
2026-10-15 | M1 mobile : textes neutres en genre (« Te revoilà », « Toujours au volant », « côté passager ») | revue UX : éviter le masculin par défaut
