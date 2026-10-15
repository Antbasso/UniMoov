# Feuille de route d'implémentation

Travaille dans l'ordre. Chaque jalon est livrable, testé et documenté avant de passer au suivant. Les références (§) renvoient au cahier des charges.

## M0 – Fondations
- Backend : migration vers TypeScript strict, Fastify, config Zod, lint/typecheck/tests (vitest), migrations Drizzle depuis `docs/data-model.sql`, `GET /health`, seed (campus Annecy, quelques utilisateurs).
- Docker Compose : `db` (PostGIS) et `api`.
- Mobile : projet Flutter dans `mobile/`, thème généré depuis `docs/design-system/tokens.json`, polices, composants `Um*`, routage, client API, i18n français.
- CI GitHub Actions : lint, typecheck, tests.
- **Accepté si** : `docker compose up` démarre API + base ; l'app affiche un écran d'accueil aux couleurs de la marque en thème clair et sombre ; la CI est verte.

## M1 – Inscription et profil (§1, §2, §12)
- Code par mail universitaire (fournisseur de mail derrière une interface, journal console en dev), mot de passe, Google/Apple, JWT + refresh.
- Onboarding par étapes avec « passer », mode découverte limité, profil, véhicule, rôle (auto/forcé), pause programmable.
- **Accepté si** : un utilisateur s'inscrit, passe l'onboarding, quitte et reprend ; tests d'intégration auth et contrôle d'accès.

## M2 – Agenda et propositions (§3, §4)
- Import ICS/CalDAV (puis Google, Microsoft Graph) avec consentement ; saisie manuelle de secours ; `schedule_slots`.
- Génération hebdomadaire des besoins, matching v1 (seuil de détour, départage, rôle automatique) en fonctions pures testées ; écran « ma semaine » avec accepter/refuser/voir d'autres.
- Relance automatique sur changement d'agenda ; recherche manuelle avec quota ; confidentialité avant acceptation.
- **Accepté si** : sur le jeu de seed, la semaine d'un étudiant génère les bonnes propositions ; un changement d'horaire les recalcule ; aucun champ sensible dans les réponses avant acceptation (test automatisé).

## M3 – Trajet confirmé, carte et prix (§5, §14)
- Confirmation à deux, trajets et arrêts ordonnés (itinéraire via le fournisseur), prix estimé et simulation pour le conducteur, `app_settings`.
- Écran carte : tracé, marqueurs d'arrêts avec adresses (selon droits), ETA, point de rendez-vous remplaçant l'adresse.
- **Accepté si** : la carte montre le conducteur et les passagers acceptés avec leur adresse ou point de rendez-vous ; un non-participant reçoit 403.

## M4 – Départ, suivi en direct et GPS externe (§9, §14, §15)
- Démarrage du trajet, WebSocket de position, ETA mis à jour, « dernière position connue », géolocalisation en arrière-plan avec écrans d'explication des permissions.
- Écran conducteur « Départ » : liste ordonnée des arrêts, bouton « Lancer la navigation », détection des apps (Google Maps, Waze, Apple Plans), choix mémorisé, mode arrêt par arrêt pour Waze, bouton « monté ».
- Validation de présence par proximité, clôture manuelle et automatique, prix final et paiement par passager (`PaymentProvider` factice).
- **Accepté si** : deux simulateurs (conducteur, passager) montrent la position du conducteur en direct ; le lien Google Maps contient tous les arrêts dans l'ordre ; les liens sont couverts par des tests unitaires ; la présence validée déclenche le paiement ; la diffusion s'arrête à la clôture.

## M5 – Annulations, confiance, litiges (§7, §8, §10)
- Annulation avec pénalité dégressive, notification, relance de remplaçant ; notes croisées, score de fiabilité utilisé dans le matching ; litiges niveau 1 automatique puis contact humain ; signalements.
- **Accepté si** : cas d'annulation tardive/précoce/absence testés unitairement ; le score influence le classement du matching.

## M6 – Messagerie et notifications (§6, §11)
- Conversations directes, groupes, chat de trajet automatique, rétention (archive puis suppression), push FCM, rappel H-1, préférences fines.
- **Accepté si** : un chat est créé à la confirmation et archivé après la durée configurée ; un utilisateur n'accède qu'à ses conversations.

## M7 – Finitions pilote
- Mode découverte, états vides/erreur, accessibilité, export et suppression de compte, internationalisation, journaux sans données personnelles, tests d'intégration du parcours complet, documentation de déploiement, performances (batterie en suivi, volume de positions).
- **Accepté si** : parcours inscription → proposition → trajet → clôture → note passe en test d'intégration ; checklist RGPD du cahier remplie.

## Hors périmètre (V2)
QR code d'accès aux places réservées, matching global, version personnalisable pour partenaires.
