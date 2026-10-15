# Contrat d'API

Base : `/api/v1`, JSON, UTF-8. Authentification `Authorization: Bearer <jwt>` sauf mention. Erreurs : `{ "error": { "code": "string", "message": "string" } }` avec statuts HTTP standards. Les schémas Zod dans `backend/src/modules/*/schema.ts` font foi pour les corps ; ce document fixe les routes et règles. La spécification OpenAPI est générée depuis les schémas Zod et publiée sur `/docs` en développement (`NODE_ENV=development`).

## Auth (sans JWT)
- `POST /auth/signup/request-code` `{ universityEmail }` → `202` : envoie le code de confirmation (6 chiffres, 10 min, usage unique, 5 essais). Domaines autorisés : `app_settings.auth.allowedEmailDomains`. Réponse identique si le compte existe déjà (un mail « tu as déjà un compte » part à la place du code). `429 code_cooldown` si un code a été demandé il y a moins d'une minute.
- `POST /auth/signup/verify` `{ universityEmail, code, firstName, lastName, password }` → `201` jetons : crée le compte vérifié, rattaché au campus pilote. `400 code_invalid` (faux, expiré, déjà utilisé ou bloqué), `409 account_exists`.
- `POST /auth/login` `{ universityEmail, password }` → `200` jetons ; `401 invalid_credentials` identique que le compte existe ou non. (`/auth/login/google` et `/auth/login/apple` : v1.1.)
- `POST /auth/refresh` `{ refreshToken }` → `200` nouveaux jetons. Chaque refresh token ne sert qu'une fois ; présenter un jeton déjà échangé révoque toute la session (`401 invalid_refresh_token`).
- `POST /auth/logout` `{ refreshToken }` → `204` : révoque la session.
- Jetons : `{ accessToken, refreshToken, accessTokenExpiresIn }` ; JWT d'accès HS256 de 15 min, refresh opaque de 30 jours.
- Limites de débit par IP : envoi de code 5/15 min, vérification et connexion 10/15 min, refresh et logout 30/min (`429 rate_limited`).

## Profil
- `GET /me` : profil privé (`home` avec adresse, coordonnées et secteur, `vehicle`, `roleMode`, `onboarding: { steps, nextStep, completed }`, `discoveryMode` tant que l'adresse ou le campus manque, `pausedToday`).
- `PATCH /me` `{ firstName?, lastName? }` ; le mail n'est pas modifiable. `DELETE /me` (suppression) et `GET /me/export` (export RGPD) : M7.
- `PUT /me/address` `{ address }` : géocode côté serveur, calcule `home_sector` ; `422 address_not_found`, `503 geocoding_unavailable`.
- `PUT /me/vehicle` `{ consumptionLPer100km, defaultSeats, maxDetourMinutes }` (un seul véhicule), `DELETE /me/vehicle` (repasse en `always_passenger`).
- `PATCH /me/preferences` `{ roleMode?, defaultNavApp? }` : `auto` et `always_driver` exigent un véhicule (`409 vehicle_required`). Détour max : dans le véhicule ; notifications : M6.
- `PUT /me/onboarding/{step}` `{ status: "done" | "skipped" }`, étapes `profile`, `vehicle`, `preferences`, `calendar` : l'app reprend à `onboarding.nextStep`.
- `GET /me/pauses`, `POST /me/pauses` `{ startsOn, endsOn, recurrence: null | "weekly:2" | "weekly:3" | "weekly:4" }` (une semaine sur N, un an au plus), `DELETE /me/pauses/{id}` (404 si la pause n'appartient pas à l'utilisateur).
- `GET /users/{id}/public` : prénom, photo, score uniquement.

## Agenda
- `POST /calendar/connections` (ICS, CalDAV, Google, Microsoft) avec `consent: true` ; `DELETE /calendar/connections/{id}` ; `POST /calendar/sync`.
- `PUT /schedule/manual` `{ days: [{ day, startTime, endTime }] }`.
- `GET /schedule?from=&to=`.

## Propositions et recherche
- `GET /proposals?week=YYYY-Www` : propositions de trajets de la semaine.
- `POST /proposals/{id}/accept` ; `POST /proposals/{id}/decline` ; `GET /proposals/{id}/alternatives`.
- `GET /search/rides?from=&to=&time=&maxDistance=` : recherche manuelle (quota quotidien, 429 au-delà).
- Avant acceptation mutuelle, les personnes sont représentées par : `firstName`, `photoUrl`, `sector` (centre de grille), `time`, `reliabilityScore`, `detourMinutes`. Jamais d'adresse exacte ni de nom de famille.
- Conducteur uniquement : `GET /rides/{id}/suggestions` (passagers supplémentaires, y compris hors seuil, avec `estimatedPricePerPerson` simulé).

## Trajets
- `GET /rides?status=` ; `GET /rides/{id}` : participants, arrêts ordonnés, `eta`, prix estimé ; coordonnées exactes selon les droits (voir ci-dessus).
- `PUT /rides/{id}/me/pickup` `{ useMeetingPoint, label, lat, lon }`.
- `POST /rides/{id}/cancel` ; effets : pénalité de score, notification, relance du matching.
- `POST /rides/{id}/start` (conducteur) : passe en `in_progress`, ouvre le suivi en direct.
- `POST /rides/{id}/participants/{userId}/picked-up` (conducteur) : « monté ».
- `POST /rides/{id}/presence` : tentative de validation de présence (le serveur compare les positions).
- `POST /rides/{id}/finish` : clôture manuelle ; clôture automatique côté serveur à l'arrivée.
- `GET /rides/{id}/price` : estimation ; le prix final est calculé à la clôture.

## Navigation (conducteur uniquement)
- `GET /rides/{id}/navigation` →
```json
{
  "stops": [
    { "order": 1, "userId": "…", "firstName": "Léa", "label": "12 rue …", "lat": 45.9, "lon": 6.12, "eta": "2026-10-20T07:42:00Z", "pickedUp": false },
    { "order": 2, "kind": "campus", "label": "Campus d'Annecy", "lat": 45.92, "lon": 6.15 }
  ],
  "links": {
    "googleMaps": "https://www.google.com/maps/dir/?api=1&…",
    "appleMaps": "https://maps.apple.com/?…",
    "waze": { "nextStop": "https://waze.com/ul?ll=45.9,6.12&navigate=yes" }
  },
  "supportsMultiStop": { "googleMaps": true, "appleMaps": true, "waze": false }
}
```
Le serveur n'inclut ce corps que pour le conducteur d'un trajet `confirmed` ou `in_progress`.

## Suivi en direct (WebSocket)
`GET /ws/rides/{rideId}?token=<jwt>` (upgrade). Messages JSON :
- Client → serveur : `{ "type": "position", "lat": 0, "lon": 0, "accuracy": 8, "speed": 12.5, "ts": "ISO-8601" }`.
- Serveur → client : `{ "type": "position", "userId": "…", "lat": …, "lon": …, "ts": "…" }`, `{ "type": "eta", "userId": "…", "eta": "…" }`, `{ "type": "stop_picked_up", "userId": "…" }`, `{ "type": "ride_status", "status": "in_progress" }`, `{ "type": "stops_reordered", "stops": [...] }`.
- Règles : refus (code 4403) si l'utilisateur n'est pas un participant confirmé ; fermeture à la clôture ; limite de 1 message de position toutes les 2 s par client.

## Portefeuille et paiements
- `GET /wallet` : solde, montant retenu, historique paginé.
- `POST /wallet/topups` `{ amountCents }` (minimum `app_settings.wallet.minTopupCents`) → renvoie la session de paiement du prestataire ; confirmation par webhook.
- `POST /wallet/payouts` (conducteur, solde au-dessus du seuil, limite hebdomadaire) ; `GET /wallet/payouts`.
- `POST /webhooks/payments` : webhooks du prestataire, signature vérifiée, idempotents.
- Réservation d'un trajet : refus `402 insufficient_funds` si le solde ne couvre pas le prix estimé plus la marge.
- Montants toujours en centimes (entiers).

## Messagerie
- `GET /conversations`, `POST /conversations` (direct ou groupe), `GET /conversations/{id}/messages?before=`, `POST /conversations/{id}/messages`.
- Le chat de trajet est créé automatiquement à la confirmation.
- Temps réel des messages : même socket utilisateur `GET /ws/me` (événements `message`).

## Confiance, litiges, notifications
- `POST /rides/{id}/ratings` ; `GET /me/reliability`.
- `POST /rides/{id}/disputes` ; `POST /reports`.
- `GET/PUT /me/notification-preferences` ; `POST /devices` `{ platform, pushToken }`.
