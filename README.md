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

## Fonctionnalités

- **Synchronisation de l'agenda de cours** (ICS/CalDAV, Google Calendar, Microsoft Graph) et planning hebdomadaire à confirmer ou ajuster.
- **Matching** par zone de départ, créneau et préférences (conducteur, passager ou les deux).
- **Confirmation à deux** : aucun trajet n'est réservé sans l'accord des deux parties.
- **Adaptation rapide** : cours annulé ou déplacé, nouvelle proposition automatique.
- Authentification universitaire et accès par QR code aux places de covoiturage réservées.
- Parrainage, points et récompenses, suivi des économies et de l'impact environnemental.

## Stack

| Couche | Technologie |
|---|---|
| Mobile | Flutter (Android / iOS) |
| Back-end | Node.js |
| Base de données | PostgreSQL |
| Agendas | lien ICS/CalDAV (Google et Microsoft en v1.1) |
| Cartographie | OpenStreetMap (PMTiles), Base Adresse Nationale, OpenRouteService |
| Déploiement | Docker |

Sécurité, consentement lors de la connexion des agendas, minimisation des données et RGPD sont des exigences dès la conception.

## Structure

```
mobile/    application Flutter
backend/   API Node.js
docs/      cahier des charges, fiche projet, étude, présentation, design system
assets/    logo et visuels
```

## Documentation

- [Cahier des charges fonctionnel](docs/cahier-des-charges.md) : fonctionnalités v1 (pilote) et pistes v2.
- [Design system](docs/design-system/README.md) : marque, tokens (`tokens.json`), composants et polices.
- [Contrainte de coût et budget](docs/couts.md) : choix techniques économiques, coûts estimés.
- [Fiche projet](docs/fiche-projet.md), [étude](docs/etude.md), [présentation](docs/presentation.md).

## Démarrage (développement)

```bash
cp .env.example .env
docker compose up -d db        # PostgreSQL
cd backend && npm install && npm start   # API sur http://localhost:3000
```

L'application Flutter sera initialisée dans `mobile/` (`flutter create .`).

## Modèle économique

B2B2C : partenariats avec l'université, les collectivités, la Région, les BDE et le CROUS, complétés par une faible commission par trajet. Pilote à Annecy, puis campus USMB, puis autres établissements.
