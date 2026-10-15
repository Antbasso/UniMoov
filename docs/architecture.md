# Architecture technique

Complète `docs/cahier-des-charges.md` (le quoi) par le comment. Un seul back-end modulaire (monolithe) et une app Flutter ; pas de microservices en v1.

## 1. Vue d'ensemble
```
Flutter app ──HTTPS REST──▶ API Fastify ──▶ PostgreSQL + PostGIS
     │                        │  ├─ pg-boss (jobs : matching, rappels, rétention)
     └──WebSocket (trajet)───▶│  ├─ Fournisseur d'itinéraires/géocodage
     ◀──Push (FCM/APNs)───────┘  ├─ Fournisseur d'agendas (ICS, Google, Microsoft)
                                 └─ PaymentProvider, MailProvider (interfaces)
```

## 2. Modules back-end (`backend/src/modules/`)
| Module | Rôle | Cahier |
|---|---|---|
| `auth` | code mail universitaire, mot de passe, Google/Apple, JWT + refresh | §1 |
| `profile` | profil, adresses, véhicule, rôle, préférences, pause | §2, §12 |
| `calendar` | connexion et synchro d'agenda, créneaux | §3 |
| `matching` | propositions hebdomadaires, seuil de détour, départage | §3, §4 |
| `rides` | trajets, arrêts, statuts, annulations, clôture | §8, §9 |
| `pricing` | estimation et prix final, commission | §5 |
| `payments` | paiement par passager via `PaymentProvider` | §5 |
| `chat` | messages privés, groupes, chat de trajet, rétention | §6 |
| `trust` | notes croisées, score de fiabilité | §7 |
| `disputes` | arbitrage automatique puis humain | §10 |
| `notifications` | push, préférences, rappels à H-1 | §11 |
| `tracking` | position en direct, ETA, WebSocket | §14 |
| `navigation` | génération des liens GPS et de l'ordre des arrêts | §15 |
| `settings` | `app_settings` (commission, prix carburant, seuils, rétention) | §5 |

Chaque module : `routes.ts` (HTTP, validation Zod), `service.ts` (logique), `repo.ts` (SQL/Drizzle), `schema.ts` (Zod + types). Les modules ne s'appellent que par leur `service`.

## 3. Données
Schéma de référence : `docs/data-model.sql`. Géométries en WGS84 (`geography(Point,4326)`), index GiST. Migrations versionnées dans `backend/migrations/`. Toutes les dates en UTC (`timestamptz`), conversion à l'affichage en `Europe/Paris`.

## 4. Matching (v1)
1. Un job hebdomadaire (et à chaque changement d'agenda) génère, par utilisateur et par créneau, un besoin de trajet (direction, heure cible, zone).
2. Candidats : conducteurs dont le trajet de base passe près du domicile du passager. Détour calculé par le fournisseur d'itinéraires (temps ajouté) ; refusé s'il dépasse le seuil du conducteur.
3. Conflit de places : on garde le plus court détour, départagé par le score de fiabilité. Fonction pure `rankCandidates()` testée unitairement.
4. Rôle automatique : si véhicule déclaré et mode auto, choisir conducteur ou passager selon l'offre et la demande du créneau (fonction pure `assignRole()`).
5. Le résultat est une proposition à confirmer par chaque partie ; aucune réservation sans accord mutuel.

## 5. Carte (mobile)
- Bibliothèque : `flutter_map` avec tuiles d'un fournisseur sous contrat ; clé dans la configuration, jamais dans le code.
- Écran `RideMapScreen` : tracé (polyline), marqueurs d'arrêts numérotés dans l'ordre de ramassage, marqueur du conducteur animé, destination. Panneau bas : liste des arrêts avec ETA.
- Visibilité : l'API ne renvoie les coordonnées exactes d'un passager qu'après acceptation mutuelle ; avant, uniquement le centre de son secteur (arrondi à une grille d'environ 500 m, calculé côté serveur).
- Point de rendez-vous : si défini par le passager, c'est ce point qui remplace son adresse dans toutes les réponses destinées au conducteur.

## 6. Suivi en direct
- Connexion WebSocket `wss://…/ws/rides/{rideId}` authentifiée par JWT ; le serveur vérifie que l'utilisateur est participant confirmé.
- Le conducteur et les passagers envoient `position` (lat, lon, précision, vitesse, horodatage) toutes les 3 à 5 s pendant un trajet en cours ; le serveur diffuse aux autres participants (le passager reçoit celle du conducteur ; le conducteur reçoit celles des passagers non montés) et calcule l'ETA par arrêt.
- Le trajet passe en `in_progress` au départ déclaré par le conducteur ; la diffusion s'arrête à `completed` ou `cancelled`. Les positions sont gardées en mémoire (dernière valeur) et une trace réduite est stockée uniquement pour l'arbitrage des litiges, avec rétention courte (`app_settings`).
- Reconnexion automatique avec backoff côté mobile ; si plus de position reçue depuis 30 s, afficher « dernière position connue ».
- Mobile : géolocalisation en arrière-plan (service de premier plan sur Android avec notification permanente, mode « location always/when in use » sur iOS) avec écran d'explication avant la demande de permission. Économie de batterie : fréquence réduite à l'arrêt.
- Validation de présence (cahier §9) : le serveur compare les positions du passager et du conducteur au point de ramassage (rayon configurable, par défaut 150 m) ; succès ⇒ présence validée ⇒ déclenche le paiement du passager.

## 7. Navigation GPS externe
Endpoint `GET /rides/{id}/navigation` (conducteur uniquement) renvoie les arrêts ordonnés et des liens prêts à ouvrir. Le mobile construit/ouvre le lien via `url_launcher` après avoir détecté les applications disponibles (`canLaunchUrl`, avec les schémas déclarés dans `Info.plist` `LSApplicationQueriesSchemes` : `comgooglemaps`, `waze`, `maps`; et `queries` dans `AndroidManifest.xml`).

| Application | Plusieurs arrêts | Lien |
|---|---|---|
| Google Maps | oui (waypoints) | `https://www.google.com/maps/dir/?api=1&origin=LAT,LON&destination=LAT,LON&waypoints=LAT,LON|LAT,LON&travelmode=driving` |
| Apple Plans | oui (iOS récent) | `https://maps.apple.com/?saddr=LAT,LON&daddr=LAT,LON+to:LAT,LON&dirflg=d` (vérifier sur appareil ; sinon arrêt par arrêt) |
| Waze | non (une destination) | `https://waze.com/ul?ll=LAT,LON&navigate=yes` |
| Autres / secours | selon appli | lien `geo:LAT,LON` (Android) ou partage système |

Règles :
- Si l'application choisie n'accepte qu'une destination, ou si le lien multi-arrêts échoue, passer en mode arrêt par arrêt : bouton « Arrêt suivant » qui relance la navigation vers le point suivant dès que le passager est marqué « monté ».
- Mémoriser l'application par défaut dans les préférences ; proposer la liste des applications installées au premier lancement.
- Les liens ne contiennent que des coordonnées, jamais de nom ni d'information personnelle.
- Le service construisant les liens (`navigation/links.ts`, fonctions pures) est testé unitairement, ainsi que l'ordre des arrêts (optimisé par le fournisseur d'itinéraires, arrivée au campus à l'heure cible).

## 8. Notifications
FCM pour Android et iOS. Table des préférences par type d'événement ; rappels de trajet à H-1 planifiés par pg-boss et annulés si le trajet change.

## 9. Sécurité et conformité
- JWT d'accès courts (15 min) + refresh rotatifs ; secrets en variables d'environnement.
- Contrôle d'accès par ressource, tests dédiés (un utilisateur ne lit jamais le trajet, le chat ou la position d'un autre trajet).
- Chiffrement en transit (TLS) ; chiffrement au repos géré par l'hébergeur ; sauvegardes.
- Registre des traitements, durées de rétention dans `app_settings` : chat de trajet (à définir), traces de position (courte), tokens d'agenda (révocables, supprimés à la déconnexion).
- Modération : signalement d'un utilisateur ou d'un message, accessible depuis le profil et le chat.

## 10. Environnements et déploiement
`docker-compose.yml` pour le développement. Image Docker du back-end ; CI (GitHub Actions) : lint, typecheck, tests back et mobile à chaque PR. Configuration par variables d'environnement validées au démarrage (Zod).
