# AGENTS.md – UniMoov

Instructions pour les agents de code. Lis ce fichier en entier avant toute modification, puis les documents listés dans « Sources de vérité ».

## Le produit en bref
UniMoov : application mobile (Flutter, iOS/Android, pas de web) de covoiturage domicile-campus pour étudiants. L'app lit l'emploi du temps, propose chaque semaine les trajets, met en relation conducteurs et passagers, partage les frais, affiche une carte avec suivi en direct et lance la navigation dans l'app GPS du conducteur. Pilote : campus USMB d'Annecy.

## Sources de vérité (ordre de priorité)
1. `docs/cahier-des-charges.md` : le QUOI. Fonctionnalités v1 (pilote) et v2. Ne code pas ce qui est marqué V2 sauf demande explicite.
2. `docs/architecture.md` : le COMMENT (stack, modules, temps réel, cartes, sécurité).
3. `docs/data-model.sql` : schéma PostgreSQL/PostGIS de référence.
4. `docs/api.md` : contrat REST et WebSocket.
5. `docs/roadmap.md` : l'ordre des jalons et les critères d'acceptation. Travaille jalon par jalon.
6. `docs/design-system/` : tokens, composants, ton éditorial. Tout l'UI en dépend.
Si deux documents se contredisent, le cahier des charges gagne ; signale la contradiction dans ta réponse et corrige l'autre document. Si une information manque, choisis la valeur par défaut la plus simple, note-la dans `docs/decisions.md` (une ligne : date, décision, raison) et continue ; ne bloque pas.

## Structure du dépôt
```
mobile/     app Flutter (feature-first : lib/features/<feature>/{data,domain,presentation})
backend/    API Node.js + TypeScript (src/modules/<module>/{routes,service,repo,schema})
docs/       spécifications (voir ci-dessus)
assets/     logo
```

## Contrainte de coût (prioritaire)
Projet étudiant à commission limitée : coût de fonctionnement visé d'environ 5 à 7 € par mois et temps de développement minimal. Lis `docs/couts.md` avant de choisir un service ou une dépendance. Règles courtes : un seul VPS en Docker Compose, aucun service payant ou managé sans validation, fournisseurs derrière des interfaces, appels externes minimisés et mis en cache, rien de v1.1 en v1 (connexion Google/Apple, agenda Google/Microsoft, pièces jointes de chat).

## Stack imposée
- Mobile : Flutter stable, Dart null-safe, Riverpod (état), go_router, dio, freezed + json_serializable, flutter_secure_storage, geolocator, url_launcher, firebase_messaging, flutter_map + flutter_map_pmtiles pour la carte (fond OSM en PMTiles statique, voir `docs/couts.md`).
- Backend : Node.js LTS, TypeScript strict, Fastify, Zod (validation, source des types), Drizzle ORM + migrations SQL, WebSocket (`@fastify/websocket`), jobs avec pg-boss (file dans PostgreSQL, pas de Redis en v1).
- Données : PostgreSQL 16 + PostGIS. Géocodage : Base Adresse Nationale. Itinéraires : OpenRouteService (palier gratuit) derrière `RoutingProvider`, OSRM/Valhalla auto-hébergé en plan B. Mail : palier gratuit derrière `MailProvider`.
- Dev : Docker Compose (`db`, `api`), `.env` non commité (`.env.example` à jour).
- Le `backend/src/index.js` actuel est un squelette JavaScript : migre-le en TypeScript au jalon M0.

## Commandes (à garder à jour dans ce fichier)
```bash
docker compose up -d db        # base locale
cd backend && npm run dev      # API :3000
cd backend && npm test         # tests (vitest)
cd backend && npm run lint && npm run typecheck
cd mobile && flutter pub get && flutter analyze && flutter test
cd mobile && flutter run
```
Avant de déclarer un travail terminé, lance lint, typecheck et tests des parties touchées et donne le résultat réel. Si une commande n'existe pas encore, crée-la dans le même changement.

## Règles non négociables
**Confidentialité et RGPD**
- Avant acceptation mutuelle, n'expose jamais le nom complet ni l'adresse exacte : uniquement prénom, photo, secteur approximatif, horaire, score, détour. C'est le serveur qui filtre (les champs sensibles ne quittent pas l'API), jamais le client.
- La position en direct n'est collectée et diffusée que pendant un trajet confirmé, uniquement aux participants de ce trajet, et supprimée à la clôture (garde au plus la trace nécessaire aux litiges, durée dans `docs/decisions.md`).
- Consentement explicite avant connexion d'un agenda ; ne stocke que les créneaux utiles (début/fin de journée, lieu), pas les titres ni descriptions d'événements.
- Aucune donnée personnelle dans les logs, aucune clé ou secret dans le code.
- Prévois export et suppression de compte.

**Argent**
- Commission, prix du carburant et seuils sont des paramètres de configuration (table `app_settings`), jamais codés en dur.
- Montants en centimes (entiers), jamais en flottants. Calcul du prix : consommation × distance × prix du carburant, divisé par les personnes réellement présentes (voir cahier, section 5).
- Paiement dans l'app via un portefeuille prépayé (cahier §5, `docs/couts.md`). Registre comptable en écriture seule (`wallet_ledger`, solde = somme des écritures, jamais de mise à jour d'une écriture), opérations idempotentes (clé d'idempotence), transactions SQL. UniMoov ne détient pas les fonds : tout passe par l'interface `PaymentProvider` ; commence par `FakePaymentProvider` complet (recharge, débit, retrait, échec), puis le vrai prestataire quand l'équipe fournit compte et clés. Ne manipule jamais de numéro de carte.

**Sécurité**
- Toute entrée API est validée par Zod. Toute route (sauf inscription/connexion) exige un JWT valide ; vérifie l'appartenance de l'utilisateur à la ressource (trajet, conversation) à chaque requête.
- Limite de débit sur connexion, envoi de code, recherche manuelle (quota quotidien du cahier).
- Mots de passe hachés avec argon2 ; codes de confirmation à usage unique et à durée courte.

**Qualité**
- Pas de logique métier dans les routes ni dans les widgets : services côté backend, use cases/notifiers côté mobile.
- Le matching, la tarification, le score de fiabilité et la génération du tracé sont des fonctions pures avec tests unitaires (cas limites inclus).
- Changements petits et ciblés ; un commit par unité logique, message à l'impératif en français ou anglais (reste cohérent).
- N'ajoute pas de dépendance sans raison ; justifie-la dans `docs/decisions.md`.

## Conventions UI (Flutter)
- Génère le thème Flutter depuis `docs/design-system/tokens.json` (couleurs clair/sombre, typographies, espacements, rayons) dans `mobile/lib/core/theme/`. Aucune couleur, taille ou rayon codé en dur dans les widgets.
- Polices : UniMoov Display (titres, prix) depuis `docs/design-system/fonts/`, Poppins pour le texte, Caveat pour une annotation par écran. Copie la police dans `mobile/assets/fonts/`.
- Composants réutilisables dans `mobile/lib/core/widgets/` : `UmButton` (primary/secondary/ghost), `UmChip`, `UmField`, `UmCard`, `UmRideCard`, `UmBenefit` (voir `docs/design-system/components/`).
- Ton : tutoiement, phrases courtes, casse de phrase, nom écrit « Uni-Moov » dans les textes visibles, une seule exclamation par écran, pas d'emoji. Textes en français, centralisés pour traduction (`intl`/ARB).
- Accessibilité : contrastes 4.5:1, zones tactiles 48 px minimum, anneau de focus, statut jamais par la couleur seule, labels sémantiques pour les lecteurs d'écran.
- Chaque écran gère quatre états : chargement, vide, erreur, contenu.

## Cartes, temps réel et navigation GPS
Détails dans `docs/architecture.md` (sections 5 à 7). Points d'attention :
- La position en direct passe par WebSocket, une salle par trajet ; le mobile envoie sa position toutes les quelques secondes avec géolocalisation en arrière-plan (permissions Android/iOS expliquées à l'utilisateur).
- Le lancement GPS utilise des deep links (Google Maps, Waze, Apple Plans) via `url_launcher` ; Waze n'accepte qu'une destination, donc navigation arrêt par arrêt pour lui.

## Tests attendus
- Backend : tests unitaires des services purs, tests d'intégration des routes avec une base PostgreSQL de test (Docker), jeu de données de seed réaliste (campus Annecy).
- Mobile : tests unitaires des notifiers et des mappers, golden tests ou widget tests des composants du design system, au moins un test d'intégration du parcours inscription → trajet confirmé.

## Définition de « terminé » d'un jalon
Les critères d'acceptation du jalon dans `docs/roadmap.md` sont remplis, lint/typecheck/tests passent, le README et `AGENTS.md` (commandes) sont à jour, les décisions prises sont dans `docs/decisions.md`.

## Ce que tu ne fais pas
- Pas de version web, pas de fonctionnalité V2 (QR code d'accès aux places, matching global) sans demande.
- Pas de réécriture du cahier des charges pour l'adapter au code : propose la modification et signale-la.
- Pas de `git push --force`, pas de commit de secrets, pas de modification des fichiers `docs/design-system/` sauf pour y corriger une erreur évidente.
