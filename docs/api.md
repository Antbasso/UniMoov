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
- `POST /calendar/connections` `{ provider: "ics", url, consent: true }` → `201` `{ connection, changedDays }` : le lien (ICS ou `webcal://`) est lu tout de suite ; `400 calendar_url_invalid` (HTTPS sur le port 443 uniquement, aucune adresse interne), `422 calendar_unreachable` ou `calendar_invalid` ; rien n'est enregistré en cas d'échec. Le lien est chiffré en base et n'est jamais renvoyé. Une seule connexion par utilisateur. CalDAV : via le lien d'abonnement ICS que les serveurs CalDAV publient ; Google et Microsoft : v1.1.
- `GET /calendar/connections` → `{ connection: { id, provider, consentedAt, lastSyncedAt, lastError } | null }`.
- `POST /calendar/sync` → `{ connection, changedDays }` ; également chaque nuit (tâche planifiée). `DELETE /calendar/connections/{id}` : lien et créneaux de l'agenda supprimés, la semaine type reprend.
- `GET/PUT /schedule/manual` `{ days: [{ weekday: 1..7, startTime: "HH:MM", endTime: "HH:MM" }] }` (semaine type, heure de Paris) → `{ days, changedDays }`.
- `GET /schedule?from=AAAA-MM-JJ&to=AAAA-MM-JJ` → `{ slots: [{ day, start, end }] }` : créneaux effectifs (agenda connecté, sinon semaine type). Seuls le début et la fin de chaque journée sont stockés, jamais les titres ni les lieux.
- Tout changement de créneau relance les propositions des jours concernés (cahier §3).

## Propositions et recherche
- `GET /proposals?week=AAAA-Www` → `{ week, proposals: [...] }`. La semaine est générée une fois (à la première lecture ou par la tâche du vendredi), puis seulement relancée sur changement d'horaire, de pause ou de profil. Chaque proposition : `{ id, day, direction, time, role, myStatus, rideStatus, seatsTotal, seatsTaken, detourMinutes, driver, passengers }` ; un conducteur sans passager reçoit aussi sa proposition.
- `POST /proposals/{id}/accept` → la proposition à jour. Le trajet passe `confirmed` quand le conducteur et au moins un passager ont accepté. Accepter un trajet où l'on n'est pas (trouvé par « voir d'autres » ou la recherche) y ajoute l'utilisateur après revérification des places, de l'horaire et du détour (`409 ride_unavailable`) ; sa proposition précédente sur le même créneau est retirée.
- `POST /proposals/{id}/decline` → `204` ; seulement avant d'avoir accepté (`409 already_answered` ; l'annulation après acceptation arrive en M5). Un passager qui refuse n'est plus proposé à ce conducteur ce jour-là ; un conducteur qui refuse annule le trajet et ses passagers sont relancés.
- `GET /proposals/{id}/alternatives` → `{ rides: [{ rideId, day, direction, time, seatsLeft, driver }] }` : autres voitures compatibles, classées par détour puis fiabilité (passagers ; liste vide pour un conducteur, les suggestions avec simulation de prix arrivent en M3).
- `GET /search/rides?day=AAAA-MM-JJ&direction=to_campus|from_campus&time=HH:MM` (heure facultative si un créneau existe ce jour-là) : même format ; quota quotidien `app_settings.search.dailyQuota` (`429 search_quota_exceeded`) et limite de débit par IP.
- Avant acceptation mutuelle, les personnes sont représentées par : `userId`, `firstName`, `photoUrl`, `sector` (centre de la cellule de 500 m, arrondi), `reliabilityScore`, `detourMinutes`, `status`. Les schémas de réponse sont stricts : nom de famille, adresse et coordonnées exactes ne peuvent pas sortir de l'API.
- Conducteur uniquement : `GET /rides/{id}/suggestions` → `{ seatsLeft, current: { persons, shareCents, passengerPaysCents } | null, suggestions: [{ person, withinDetourLimit, shareCents, passengerPaysCents }] }` : passagers sans trajet ce jour-là dans ce sens, horaire compatible, y compris ceux écartés car au-delà du détour maximal (`withinDetourLimit: false`), avec le prix par passager simulé (distance estimée, comme le prix actuel). Dix au plus, par détour croissant puis fiabilité. `403 forbidden` hors conducteur, `409 accept_first` tant que le conducteur n'a pas accepté.
- `POST /rides/{id}/suggestions/{userId}/invite` → la proposition du conducteur à jour : la personne reçoit une proposition à accepter (`409 ride_full`, `409 suggestion_unavailable`).

## Trajets
- `GET /rides/{id}` (participant accepté d'un trajet `confirmed`, `in_progress` ou `completed`) → `{ id, day, direction, time, status, role, seatsTotal, distanceM, durationS, routeEstimated, route: [[lat, lon]…], stops, price }`. `403 forbidden` pour toute autre personne (y compris un participant qui n'a pas accepté), `409 ride_not_confirmed` avant la confirmation à deux, `404` si le trajet n'existe pas.
  - `stops` dans l'ordre du trajet : aller = domicile du conducteur, passagers acceptés, campus ; retour = campus, passagers, domicile du conducteur. Chaque arrêt : `{ order, kind: driver|passenger|campus, userId, firstName, lastName, label, lat, lon, eta, isMeetingPoint }`. Le point de rendez-vous remplace l'adresse dans toutes les réponses. `lastName` n'est rempli qu'entre conducteur et passager (et pour soi) : entre passagers, prénom seulement.
  - `route` : tracé simplifié ; `routeEstimated: true` si le fournisseur d'itinéraires était indisponible (lignes droites estimées).
  - Plan (ordre des arrêts, tracé, heures de passage, distance) calculé à la confirmation, puis recalculé quand un passager accepte ou change de point de rendez-vous ; aller : arrivée au campus à l'heure cible, retour : départ du campus à l'heure cible.
- `GET /rides/{id}/price` → `{ price }` : `{ estimated: true, totalCostCents, persons, shareCents, commissionCents, passengerPaysCents, driverReceivesCents, youPayCents, youReceiveCents }`, `null` si le conducteur n'a plus de véhicule. Coût = consommation × distance du tracé × `pricing.fuelPriceCentsPerLitre`, partagé entre conducteur et passagers acceptés (part arrondie au centime supérieur), plus `pricing.commissionCentsPerPassenger` pour chaque passager. Le prix final est calculé à la clôture (M4).
- `PUT /rides/{id}/me/pickup` `{ useMeetingPoint, label?, lat?, lon? }` → `204` (passager accepté, trajet pas encore commencé) : à moins de `rides.meetingPointMaxMeters` du domicile (`422 meeting_point_too_far`) ; `useMeetingPoint: false` revient à l'adresse. `403 forbidden` pour le conducteur ou un non-participant, `409 ride_locked` une fois le trajet commencé.
- `GET /rides?status=` : M4 (liste des trajets du jour, écran de départ).
- `POST /rides/{id}/cancel` ; effets : pénalité de score, notification, relance du matching (M5).
- `POST /rides/{id}/start` (conducteur) : passe en `in_progress`, ouvre le suivi en direct.
- `POST /rides/{id}/participants/{userId}/picked-up` (conducteur) : « monté ».
- `POST /rides/{id}/presence` : tentative de validation de présence (le serveur compare les positions).
- `POST /rides/{id}/finish` : clôture manuelle ; clôture automatique côté serveur à l'arrivée.

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
