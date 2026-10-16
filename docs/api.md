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
  - `stops` dans l'ordre du trajet : aller = domicile du conducteur, passagers acceptés, campus ; retour = campus, passagers, domicile du conducteur. Chaque arrêt : `{ order, kind: driver|passenger|campus, userId, firstName, lastName, label, lat, lon, eta, isMeetingPoint }`. Le point de rendez-vous remplace l'adresse dans toutes les réponses. Conducteur et passager se sont acceptés : nom de famille et adresse exacte de l'un à l'autre (et pour soi). Entre passagers, pas d'acceptation mutuelle : prénom seulement et, pour un domicile, centre du secteur avec `label` vide (le point de rendez-vous, lieu public, reste exact) ; pour un passager, le tracé est privé de ses points à moins de 500 m d'un domicile masqué.
  - `route` : tracé simplifié ; `routeEstimated: true` si le fournisseur d'itinéraires était indisponible (lignes droites estimées).
  - Plan (ordre des arrêts, tracé, heures de passage, distance) calculé à la confirmation, puis recalculé quand un passager accepte ou change de point de rendez-vous ; aller : arrivée au campus à l'heure cible, retour : départ du campus à l'heure cible.
- `GET /rides/{id}/price` → `{ price }` : `{ estimated: true, totalCostCents, persons, shareCents, commissionCents, passengerPaysCents, driverReceivesCents, youPayCents, youReceiveCents }`, `null` si le conducteur n'a plus de véhicule. Coût = consommation × distance du tracé × `pricing.fuelPriceCentsPerLitre`, partagé entre conducteur et passagers acceptés (part arrondie au centime supérieur), plus `pricing.commissionCentsPerPassenger` pour chaque passager. Le prix final est calculé à la clôture (M4).
- `PUT /rides/{id}/me/pickup` `{ useMeetingPoint, label?, lat?, lon? }` → `204` (passager accepté, trajet pas encore commencé) : à moins de `rides.meetingPointMaxMeters` du domicile (`422 meeting_point_too_far`) ; `useMeetingPoint: false` revient à l'adresse. `403 forbidden` pour le conducteur ou un non-participant, `409 ride_locked` une fois le trajet commencé.
- `GET /rides?status=` : liste des trajets du jour, plus tard (l'app passe par « Ta semaine »).
- `POST /rides/{id}/start` (conducteur accepté, trajet `confirmed`, au plus tôt `rides.startWindowMinutes` avant l'heure du trajet) → `204` : passe en `in_progress`, ouvre le suivi en direct et retient sur le portefeuille de chaque passager accepté son prix estimé plus `wallet.holdMarginPercent` (au plus ce qui est disponible). `403 forbidden` hors conducteur, `409 too_early`, `409 ride_not_confirmed`. Rejoué : sans effet.
- `POST /rides/{id}/participants/{userId}/picked-up` (conducteur, trajet en cours) → `204` : « monté » ; l'arrêt sort de la navigation (`stop_picked_up` diffusé).
- `POST /rides/{id}/presence` (passager) → `{ payment: "paid" | "failed" | "already" }` : la présence est validée si les dernières positions du passager et du conducteur sont à moins de `tracking.presenceRadiusMeters` (`409 presence_not_confirmed` sinon). Elle est aussi validée automatiquement quand les deux téléphones se rapprochent pendant le suivi. Elle déclenche le paiement du passager depuis son portefeuille (voir « Portefeuille »).
- `POST /rides/{id}/finish` (tout participant accepté) → `204` : `completed`, prix final enregistré (coût du tracé partagé entre les personnes présentes, jamais plus que la part estimée de chacun), retenues des passagers absents libérées (statut `absent`), suivi fermé. Clôture automatique quand le conducteur arrive à moins de `tracking.arrivalRadiusMeters` de la destination et que plus personne n'attend. Rejoué : sans effet.

## Navigation (conducteur uniquement)
- `GET /rides/{id}/navigation` (trajet `confirmed` ou `in_progress`) →
```json
{
  "stops": [
    { "order": 1, "kind": "passenger", "userId": "…", "firstName": "Hugo", "label": "12 rue …", "lat": 45.9, "lon": 6.12, "eta": "2026-10-20T07:42:00Z", "pickedUp": false },
    { "order": 2, "kind": "destination", "userId": null, "firstName": null, "label": "Campus d'Annecy", "lat": 45.92, "lon": 6.15, "eta": "…", "pickedUp": false }
  ],
  "links": {
    "googleMaps": "https://www.google.com/maps/dir/?api=1&destination=LAT,LON&waypoints=LAT,LON%7CLAT,LON&travelmode=driving",
    "appleMaps": "https://maps.apple.com/?daddr=LAT,LON+to:LAT,LON&dirflg=d",
    "waze": { "nextStop": "https://waze.com/ul?ll=LAT,LON&navigate=yes" }
  },
  "supportsMultiStop": { "googleMaps": true, "appleMaps": true, "waze": false }
}
```
Les liens portent les arrêts restants (pas encore montés) dans l'ordre, puis la destination (campus à l'aller, domicile du conducteur au retour) ; sans origine, l'application part de la position du téléphone. Ils ne contiennent que des coordonnées. `403` pour tout autre utilisateur.

## Suivi en direct (WebSocket)
`GET /ws/rides/{rideId}?token=<jwt>` (upgrade) ; le jeton n'est jamais journalisé. Messages JSON :
- Client → serveur : `{ "type": "position", "lat": 0, "lon": 0, "accuracy": 8, "speed": 12.5, "ts": "ISO-8601" }` ; une position toutes les 2 s au plus (les autres sont ignorées).
- Serveur → client : `{ "type": "ready", "role": "driver" | "passenger" }` (abonné ; suivi de la dernière position connue du conducteur), `{ "type": "position", "userId", "lat", "lon", "ts" }`, `{ "type": "eta", "userId", "eta" }`, `{ "type": "stop_picked_up", "userId" }`, `{ "type": "presence_validated", "userId", "payment": "paid" | "failed" }` (au passager et au conducteur), `{ "type": "ride_status", "status": "in_progress" | "completed" }`.
- Diffusion : le passager reçoit la position du conducteur et son heure de passage ; le conducteur reçoit celles des passagers pas encore montés ; jamais d'un passager à un autre.
- Fermeture : `4401` jeton invalide, `4403` pas participant accepté, `4409` trajet pas en cours, `4410` trajet clôturé. Positions gardées en mémoire, trace d'un point toutes les 30 s pour les litiges, supprimée après `tracking.traceRetentionDays`.

## Portefeuille et paiements
- `GET /wallet` → `{ balanceCents, heldCents, history: [{ kind, amountCents, rideId, createdAt }] }` (50 dernières opérations, retenues exclues).
- `POST /wallet/topups` `{ amountCents }` avec l'en-tête `Idempotency-Key` (8 à 100 caractères) → `201 { status, wallet }` ; minimum `app_settings.wallet.minTopupCents` (`400 topup_too_small`), refus du prestataire `402 topup_failed`. La même clé ne recharge qu'une fois. Fournisseur factice (`PAYMENT_PROVIDER=fake`, refusé en production) : recharge immédiate ; prestataire réel, session de paiement et webhook : M4b.
- Registre `wallet_ledger` en écriture seule (déclencheur en base) ; chaque opération est équilibrée (somme nulle) et idempotente. Comptes : `user:<id>`, `held:<id>`, `platform:commission`, `provider:clearing`.
- Paiement d'un passager à la validation de sa présence : sa retenue est libérée, il paie sa part plus la commission, le conducteur reçoit la part, Uni-Moov la commission. Solde insuffisant : paiement `failed`, jamais de solde négatif.
- `POST /wallet/payouts`, `GET /wallet/payouts`, `POST /webhooks/payments`, refus de réservation `402 insufficient_funds` : M4b.
- Montants toujours en centimes (entiers).

## Messagerie
- `GET /conversations`, `POST /conversations` (direct ou groupe), `GET /conversations/{id}/messages?before=`, `POST /conversations/{id}/messages`.
- Le chat de trajet est créé automatiquement à la confirmation.
- Temps réel des messages : même socket utilisateur `GET /ws/me` (événements `message`).

## Annulations (cahier §8)
- `GET /rides/{id}/cancellation` → `{ role, tier }` : palier de pénalité si la personne annule maintenant (`early`, `medium`, `late`, selon `reliability.penalties`). `409 not_accepted` si elle n'a pas accepté (c'est alors un refus, `POST /proposals/{id}/decline`).
- `POST /rides/{id}/cancel` → `{ tier }`, avant le départ seulement. Pénalité au score de la personne qui annule, notification immédiate des autres participants acceptés (`ride_cancelled`). Passager : sa place est proposée au meilleur passager disponible dans le détour du conducteur ; plus aucun passager accepté, le trajet redevient `proposed`. Conducteur : trajet `cancelled`, chaque passager reçoit une autre proposition si possible (`replacement_proposed`). Pas de pénalité pour les passagers d'un conducteur qui annule.

## Confiance (cahier §7)
- `GET /rides/{id}/ratings` → `{ open, closesAt, people: [{ userId, firstName, photoUrl, role, stars }] }` : trajet terminé, conducteur ↔ passagers dont la présence est validée, jamais entre passagers. `403` pour un absent ou un tiers.
- `POST /rides/{id}/ratings` `{ ratedUserId, stars }` (1 à 5, sans commentaire) → `204`. Une fois par personne (`409 already_rated`), pendant `ratings.windowDays` après la fin (`409 rating_closed`).
- `GET /me/reliability` → `{ score, windowDays, completedRides, cancellations: { early, medium, late }, noShows, ratingsCount, averageStars, events: [{ id, kind, rideId, day, createdAt, disputeReason }] }`. `disputeReason` non nul : l'entrée est encore contestable.
- Score : moyenne bayésienne du comportement (trajets menés à bien face aux pénalités) et des notes, sur `reliability.windowDays` ; il ne sert qu'à classer dans le matching (détour + `matching.reliabilityWeightSeconds` × (1 − score)), jamais à exclure.

## Litiges (cahier §10)
- `POST /rides/{id}/disputes` `{ reason, message? }` → `201 { id, rideId, reason, level, decision, explanation, createdAt, escalatedAt }`. Motifs : `cancellation_penalty`, `marked_absent`, `payment`, `driver_issue`, `other`. Niveau 1 tranché sur les horodatages du serveur (`upheld`, `corrected` avec correction du score) ; sinon niveau 2 (`escalated`), mail à `support.email`. Un litige par motif et par trajet (`409 dispute_exists`), pendant `disputes.windowDays` (`409 dispute_closed`).
- `POST /disputes/{id}/escalate` `{ message? }` : désaccord avec la décision, passage au niveau 2 (idempotent).
- `GET /rides/{id}/disputes` : mes litiges sur ce trajet. Un passager compté absent garde l'accès en lecture au trajet clôturé (`myStatus: "absent"` dans `GET /rides/{id}`).

## Signalements
- `POST /reports` `{ targetUserId, reason, message? }` → `201 { id }` ; motifs `dangerous_driving`, `inappropriate_behaviour`, `fake_profile`, `other`. Seulement une personne croisée sur un trajet (sinon `404`, comme une personne inconnue), `reports.dailyLimit` par jour (`429 report_limit`). Transmis à l'équipe par mail, jamais à la personne signalée.

## Notifications
- `GET/PUT /me/notification-preferences` ; `POST /devices` `{ platform, pushToken }` (M6). En M5, les événements `ride_cancelled` et `replacement_proposed` passent par l'interface `Notifier` (journal sans donnée personnelle, push FCM en M6).
