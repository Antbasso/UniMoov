<p align="center"><img src="assets/logo.png" alt="UniMoov" width="160"></p>

# UniMoov

**Ton emploi du temps organise aussi tes trajets.**

UniMoov est une application mobile de covoiturage domicile-campus pour les étudiants du campus USMB d'Annecy. Elle transforme les horaires de cours en propositions de trajets à confirmer, et s'adapte quand l'emploi du temps change.

> Projet d'innovation numérique – Master 2 S2IN.
> Équipe : Antoine BASSO, Lucas BATISTA, Katia GOASDUF, Lou SEMPERE.

## Pourquoi

- Enquête USMB 2022 (1 355 répondants) : 55 % des étudiants peinent à se garer.
- Freins au covoiturage : organisation et perte d'autonomie.
- Les solutions existantes (Karos Campus, BlaBlaCar Daily, MOV'ICI, groupes WhatsApp) supposent un trajet régulier, alors que l'emploi du temps ne l'est pas.

## Fonctionnalités (pilote v1, voir le cahier des charges)

- **Synchronisation de l'agenda de cours** par lien ICS/CalDAV ou saisie manuelle (Google et Microsoft en v1.1), propositions hebdomadaires à confirmer.
- **Matching** par zone de départ, créneau, seuil de détour et score de fiabilité ; rôle conducteur, passager ou automatique.
- **Confirmation à deux** : aucun trajet n'est réservé sans l'accord des deux parties ; adresse exacte masquée avant.
- **Adaptation rapide** : cours annulé ou déplacé, nouvelle proposition automatique.
- **Carte, suivi en direct et lancement du GPS** (Google Maps, Waze, Apple Plans).
- **Frais partagés** au réel via un portefeuille prépayé, messagerie, notes et mode pause.
- Évolutions v2 : accès par QR code aux places réservées, matching global.

## Stack

| Couche | Technologie |
|---|---|
| Mobile | Flutter (Android / iOS), Riverpod, go_router, dio |
| Back-end | Node.js LTS, TypeScript strict, Fastify, Zod, Drizzle |
| Base de données | PostgreSQL 16 + PostGIS |
| Agendas | lien ICS/CalDAV (Google et Microsoft en v1.1) |
| Cartographie | OpenStreetMap (PMTiles), Base Adresse Nationale, OpenRouteService |
| Déploiement | Docker Compose sur un VPS, CI GitHub Actions |

Sécurité, consentement lors de la connexion des agendas, minimisation des données et RGPD sont des exigences dès la conception.

## Structure

```
mobile/    application Flutter
backend/   API Node.js + TypeScript (Fastify), migrations SQL
docs/      cahier des charges, fiche projet, étude, présentation, design system
assets/    logo et visuels
```

## Documentation

- [Cahier des charges fonctionnel](docs/cahier-des-charges.md) : fonctionnalités v1 (pilote) et pistes v2.
- [Design system](docs/design-system/README.md) : marque, tokens (`tokens.json`), composants et polices.
- [Contrainte de coût et budget](docs/couts.md) : choix techniques économiques, coûts estimés.
- [Fiche projet](docs/fiche-projet.md), [étude](docs/etude.md), [présentation](docs/presentation.md).

## Démarrage (développement)

Prérequis : Docker, Node.js 22.12+ (24 recommandé), Flutter stable 3.47.

```bash
cp .env.example .env
docker compose up -d                 # PostGIS + API sur http://localhost:3000 (migrations au démarrage)
curl localhost:3000/health           # {"status":"ok","db":"ok"}

cd backend && npm ci
npm run db:seed                      # étudiants de démonstration autour du campus d'Annecy
npm run lint && npm run typecheck && npm test
npm run test:integration             # nécessite TEST_DATABASE_URL (voir .env.example) et une base PostGIS

cd ../mobile && flutter pub get && flutter analyze && flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Créer un compte en local : l'app (ou `POST /api/v1/auth/signup/request-code`) envoie le code par le fournisseur de mail « console », qui l'écrit dans le journal de l'API (`docker compose logs -f api`). Le contrat de l'API est consultable sur http://localhost:3000/docs en développement. Avec `GEOCODING_PROVIDER=fake`, l'adresse « 12 rue de la Paix, Annecy » est reconnue sans accès réseau.

Après `npm run db:seed`, les comptes de démonstration (par exemple `lea.martin@etu.univ-smb.fr`, conductrice, ou `ines.robert@etu.univ-smb.fr`, passagère) se connectent avec le mot de passe `unimoov-demo` ; leur semaine type est saisie et l'écran d'accueil affiche les propositions de la semaine. Après une confirmation à deux, « Voir la carte » ouvre le trajet (arrêts, heures de passage, prix estimé). Sans clé, les itinéraires sont estimés en lignes droites ; pour de vrais tracés, crée une clé gratuite sur openrouteservice.org et règle `ROUTING_PROVIDER=ors` et `ORS_API_KEY` dans `.env`. Le fond de carte est un extrait PMTiles vectoriel (schéma OpenMapTiles) de la région : `pmtiles extract france.pmtiles annecy.pmtiles --bbox=5.80,45.75,6.40,46.10`, servi en statique avec les requêtes partielles (Range) et CORS, par exemple `npx http-server -p 8080 --cors` en local, Cloudflare R2 en production ; l'app le lit avec `--dart-define=PMTILES_URL=http://10.0.2.2:8080/annecy.pmtiles`. Le fichier n'est jamais commité. Les tâches planifiées (lecture des agendas chaque nuit, génération des propositions le vendredi soir) tournent dans l'API ; `JOBS_ENABLED=false` les coupe en développement.

Pour développer l'API avec rechargement : `docker compose up -d db` puis `cd backend && npm run dev`. Toutes les commandes sont listées dans [AGENTS.md](AGENTS.md) ; l'avancement suit la [feuille de route](docs/roadmap.md) et les choix sont tracés dans le [journal des décisions](docs/decisions.md).

## Modèle économique

B2B2C : partenariats avec l'université, les collectivités, la Région, les BDE et le CROUS, complétés par une faible commission par trajet. Pilote à Annecy, puis campus USMB, puis autres établissements.
