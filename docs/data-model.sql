-- Schéma de référence UniMoov (PostgreSQL 16 + PostGIS). À transformer en migrations versionnées.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE ride_status AS ENUM ('proposed','confirmed','in_progress','completed','cancelled');
CREATE TYPE participant_role AS ENUM ('driver','passenger');
CREATE TYPE participant_status AS ENUM ('proposed','requested','accepted','declined','picked_up','absent','cancelled');
CREATE TYPE role_mode AS ENUM ('auto','always_driver','always_passenger');

CREATE TABLE app_settings (          -- commission, prix carburant, seuils, rétentions
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  university_email text NOT NULL UNIQUE,
  email_verified_at timestamptz,
  password_hash text,
  google_sub text UNIQUE,
  apple_sub text UNIQUE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  photo_url text,                          -- /api/v1/users/{id}/photo?v=… (photo dans user_photos)
  study_program text CHECK (char_length(study_program) <= 80),
  birth_year smallint CHECK (birth_year BETWEEN 1940 AND 2020),  -- âge affiché, jamais la date
  interests text[] NOT NULL DEFAULT '{}' CHECK (cardinality(interests) <= 6),
  home_address text,
  home_location geography(Point,4326),
  home_sector text,                       -- cellule de grille ~500 m, calculée côté serveur
  campus_id uuid,
  role_mode role_mode NOT NULL DEFAULT 'always_passenger',
  default_nav_app text,                   -- 'google_maps' | 'waze' | 'apple_maps' | null
  onboarding_completed_at timestamptz,
  reliability_score numeric(4,3) NOT NULL DEFAULT 0.800,
  paused_until timestamptz,
  onboarding_steps jsonb NOT NULL DEFAULT '{}'::jsonb, -- { "profile": "done" | "skipped", ... }
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX users_home_location_gix ON users USING gist (home_location);

CREATE TABLE campuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  location geography(Point,4326) NOT NULL
);

CREATE TABLE user_photos (                -- photo de profil, sauvegardée avec la base
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png')),
  data bytea NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Profil public (facultatif) et classement du campus, ajoutés à users :
ALTER TABLE users ADD COLUMN bio text CHECK (char_length(bio) <= 200);              -- mini-bio
ALTER TABLE users ADD COLUMN pref_chat text CHECK (pref_chat IN ('chatty', 'depends', 'quiet'));
ALTER TABLE users ADD COLUMN pref_music text CHECK (pref_music IN ('yes', 'depends', 'no'));
ALTER TABLE users ADD COLUMN pref_smoking text CHECK (pref_smoking IN ('ok', 'outside', 'no'));
ALTER TABLE users ADD COLUMN pref_pets text CHECK (pref_pets IN ('yes', 'some', 'no'));
ALTER TABLE users ADD COLUMN leaderboard_visible boolean NOT NULL DEFAULT false;     -- prénom au classement

CREATE TABLE vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consumption_l_per_100km numeric(4,1) NOT NULL,
  default_seats smallint NOT NULL CHECK (default_seats BETWEEN 1 AND 8),
  max_detour_minutes smallint NOT NULL DEFAULT 10,
  model text CHECK (char_length(model) BETWEEN 1 AND 40),   -- « Clio 4 », pour reconnaître la voiture
  color text CHECK (char_length(color) BETWEEN 1 AND 30)    -- « grise »
);
CREATE UNIQUE INDEX vehicles_user_id_key ON vehicles (user_id);   -- un véhicule par personne

CREATE TABLE pauses (                     -- pause programmée, récurrence optionnelle
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  recurrence text,                        -- 'weekly:N', 'monthly:N' ou 'days:1,3' (jours ISO)
  repeat_until date,                      -- fin de la répétition (avec recurrence seulement)
  CHECK ((recurrence IS NULL) = (repeat_until IS NULL) AND (repeat_until IS NULL OR repeat_until >= ends_on))
);
CREATE INDEX pauses_user_idx ON pauses (user_id);

CREATE TABLE verification_codes (         -- code d'inscription : haché (HMAC), usage unique, durée courte
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  code_hash text NOT NULL,
  purpose text NOT NULL DEFAULT 'signup' CHECK (purpose IN ('signup')),
  attempts smallint NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX verification_codes_email_idx ON verification_codes (email, created_at DESC);

CREATE TABLE refresh_tokens (             -- rotation ; famille révoquée si un jeton est réutilisé
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id uuid NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id);

CREATE TABLE calendar_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider text NOT NULL,                 -- 'ics' | 'caldav' | 'google' | 'microsoft' | 'manual'
  encrypted_credentials bytea,
  consented_at timestamptz NOT NULL,
  last_synced_at timestamptz,
  last_error text                         -- code de la dernière erreur de lecture
);
CREATE UNIQUE INDEX calendar_connections_user_key ON calendar_connections (user_id);

CREATE TABLE manual_schedule_days (       -- semaine type saisie à la main (secours sans agenda)
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),   -- 1 = lundi
  start_time time NOT NULL,
  end_time time NOT NULL CHECK (end_time > start_time),
  PRIMARY KEY (user_id, weekday)
);

CREATE TABLE schedule_slots (             -- uniquement début/fin utiles, pas de titres d'événements
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day date NOT NULL,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  place_location geography(Point,4326),
  source text NOT NULL,                   -- 'calendar' | 'manual'
  UNIQUE (user_id, day, source)
);
CREATE INDEX schedule_slots_day_idx ON schedule_slots (day);

CREATE TABLE rides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES users(id),
  direction text NOT NULL CHECK (direction IN ('to_campus','from_campus')),
  campus_id uuid NOT NULL REFERENCES campuses(id),
  day date,                               -- jour du trajet (Paris)
  target_time timestamptz NOT NULL,       -- arrivée (aller) ou départ (retour)
  seats_total smallint NOT NULL,
  status ride_status NOT NULL DEFAULT 'proposed',
  route geography(LineString,4326),
  route_estimated boolean NOT NULL DEFAULT false,  -- tracé estimé (fournisseur indisponible)
  planned_at timestamptz,                 -- dernier calcul du plan (null : à recalculer)
  distance_m integer,
  duration_s integer,
  started_at timestamptz,
  ended_at timestamptz,
  estimated_total_cost_cents integer,
  final_total_cost_cents integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX rides_target_time_idx ON rides (target_time);
CREATE INDEX rides_day_direction_idx ON rides (day, direction);

CREATE TABLE ride_participants (
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  role participant_role NOT NULL,
  status participant_status NOT NULL DEFAULT 'proposed',
  pickup_label text,                      -- adresse ou point de rendez-vous
  pickup_location geography(Point,4326),
  use_meeting_point boolean NOT NULL DEFAULT false,
  stop_order smallint,
  eta timestamptz,
  detour_s integer,
  onboard_m integer CHECK (onboard_m >= 0),  -- distance à bord depuis le campus (plan) : prix au prorata
  presence_validated_at timestamptz,
  amount_cents integer,
  cancelled_at timestamptz,
  picked_up_at timestamptz,               -- « monté » déclaré par le conducteur (arbitrage des litiges)
  PRIMARY KEY (ride_id, user_id)
);
CREATE INDEX ride_participants_user_idx ON ride_participants (user_id);

CREATE TABLE proposal_declines (          -- paire refusée : plus reproposée ce jour-là
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  other_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day date NOT NULL,
  direction text NOT NULL CHECK (direction IN ('to_campus','from_campus')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, other_user_id, day, direction)
);

CREATE TABLE matching_runs (              -- semaines déjà générées
  week text PRIMARY KEY,
  generated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE wallets (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  balance_cents integer NOT NULL DEFAULT 0,       -- cache de SUM(wallet_ledger), recalculable
  held_cents integer NOT NULL DEFAULT 0,          -- retenues en attente de clôture
  pending_cents integer NOT NULL DEFAULT 0,       -- parts reçues, versées après le délai de signalement
  provider_account_ref text,                      -- compte chez le prestataire agréé
  identity_verified_at timestamptz                -- requis pour retirer (conducteur)
);

-- Registre en écriture seule : on n'UPDATE ni ne DELETE jamais une écriture.
CREATE TABLE wallet_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE,
  account text NOT NULL,                          -- 'user:<uuid>' | 'held:<uuid>' | 'pending:<uuid>' | 'platform:commission' | 'provider:clearing'
  ride_id uuid REFERENCES rides(id),
  kind text NOT NULL,       -- topup | hold | hold_release | ride_charge | ride_credit | commission | payout | refund
  amount_cents integer NOT NULL,                  -- signé ; la somme des écritures d'une opération vaut 0
  operation_id uuid NOT NULL,                     -- regroupe les écritures équilibrées
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX wallet_ledger_account_idx ON wallet_ledger (account, created_at);
CREATE INDEX wallet_ledger_ride_idx ON wallet_ledger (ride_id);
CREATE INDEX wallet_ledger_operation_idx ON wallet_ledger (operation_id);
-- Écriture seule garantie par la base (migration 0005) : UPDATE et DELETE refusés.
CREATE FUNCTION wallet_ledger_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'wallet_ledger est en écriture seule'; END; $$;
CREATE TRIGGER wallet_ledger_no_update BEFORE UPDATE OR DELETE ON wallet_ledger
  FOR EACH ROW EXECUTE FUNCTION wallet_ledger_append_only();

CREATE TABLE topups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  provider_ref text UNIQUE,
  status text NOT NULL DEFAULT 'pending',        -- pending | succeeded | failed
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  provider_ref text UNIQUE,
  status text NOT NULL DEFAULT 'pending',        -- pending | paid | failed
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payments (                          -- un enregistrement par passager et par trajet
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES rides(id),
  payer_id uuid NOT NULL REFERENCES users(id),
  payee_id uuid NOT NULL REFERENCES users(id),
  share_cents integer NOT NULL CHECK (share_cents >= 0),       -- part des frais, versée au conducteur
  commission_cents integer NOT NULL DEFAULT 0,                  -- ajoutée au prix, versée à UniMoov
  status text NOT NULL DEFAULT 'held',           -- held | paid | failed | refunded
  held_cents integer NOT NULL DEFAULT 0 CHECK (held_cents >= 0),  -- retenu au départ
  paid_at timestamptz,
  released_at timestamptz,                       -- part versée au conducteur (après le délai, sans litige)
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_id, payer_id)
);

CREATE TABLE position_trace (             -- rétention courte, pour les litiges
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id),
  recorded_at timestamptz NOT NULL,
  location geography(Point,4326) NOT NULL,
  PRIMARY KEY (ride_id, user_id, recorded_at)
);
CREATE INDEX position_trace_recorded_idx ON position_trace (recorded_at);

CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL CHECK (kind IN ('direct','group','ride')),
  ride_id uuid REFERENCES rides(id) ON DELETE SET NULL,
  direct_key text,                         -- paire triée « a|b » : une conversation privée par paire
  title text,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz,
  archived_at timestamptz,                 -- lecture seule à partir de cette date (chat de trajet)
  delete_after timestamptz                 -- supprimé avec ses messages à partir de cette date
);
CREATE UNIQUE INDEX conversations_ride_idx ON conversations (ride_id) WHERE kind = 'ride';
CREATE UNIQUE INDEX conversations_direct_idx ON conversations (direct_key) WHERE kind = 'direct';
CREATE TABLE conversation_members (
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  last_read_at timestamptz,                -- messages non lus : postérieurs à cette date
  PRIMARY KEY (conversation_id, user_id)
);
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id),
  body text NOT NULL,                       -- vide seulement pour une photo sans légende
  has_photo boolean NOT NULL DEFAULT false,
  reply_to_id uuid REFERENCES messages(id) ON DELETE SET NULL,  -- réponse à un message (citation)
  created_at timestamptz NOT NULL DEFAULT now(),
  -- proposition de covoiturage (groupe ou privé) : offre d'un trajet, ou demande jour + sens
  carpool_kind text CHECK (carpool_kind IN ('offer', 'request')),
  carpool_ride_id uuid REFERENCES rides(id) ON DELETE SET NULL,
  carpool_day date,
  carpool_direction text CHECK (carpool_direction IN ('to_campus', 'from_campus'))
);
CREATE INDEX messages_conv_idx ON messages (conversation_id, created_at);
ALTER TABLE messages ADD CONSTRAINT messages_body_length
  CHECK (char_length(body) <= 2000 AND (char_length(body) >= 1 OR has_photo));

CREATE TABLE message_reactions (        -- une réaction par personne et par message
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji text NOT NULL CHECK (char_length(emoji) BETWEEN 1 AND 16),   -- un emoji (vérifié par l'API)
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE message_photos (           -- photo réduite par l'app, supprimée avec son message
  message_id uuid PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png')),
  data bytea NOT NULL CHECK (octet_length(data) <= 614400)
);

CREATE TABLE carpool_joins (            -- qui a accepté quelle proposition, dans quelle voiture
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE ratings (
  ride_id uuid NOT NULL REFERENCES rides(id),
  rater_id uuid NOT NULL REFERENCES users(id),
  rated_id uuid NOT NULL REFERENCES users(id),
  stars smallint NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment text,                           -- non utilisé en v1 (étoiles seulement)
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ride_id, rater_id, rated_id)
);
CREATE INDEX ratings_rated_idx ON ratings (rated_id, created_at);

CREATE TABLE reliability_events (         -- annulations, absences, etc. (entrées du score)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  ride_id uuid REFERENCES rides(id),
  kind text NOT NULL CHECK (kind IN ('completed','cancel_early','cancel_medium','cancel_late','no_show','correction')),
  weight numeric(4,3) NOT NULL,            -- correction : poids négatif (écriture seule, pas de mise à jour)
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reliability_events_user_idx ON reliability_events (user_id, created_at);
CREATE UNIQUE INDEX reliability_events_once_idx ON reliability_events (user_id, ride_id, kind)
  WHERE ride_id IS NOT NULL AND kind <> 'correction';

CREATE TABLE disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES rides(id),
  opened_by uuid NOT NULL REFERENCES users(id),
  reason text NOT NULL CHECK (reason IN ('cancellation_penalty','marked_absent','payment','driver_issue','other')),
  message text,
  level smallint NOT NULL DEFAULT 1,       -- 1 automatique, 2 humain
  decision text NOT NULL DEFAULT 'escalated' CHECK (decision IN ('upheld','corrected','escalated')),
  resolution text,                         -- code d'explication de l'arbitrage
  escalated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX disputes_once_idx ON disputes (ride_id, opened_by, reason);

CREATE TABLE notification_preferences (     -- pas de ligne = activé (cahier §11)
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('match','ride_update','ride_reminder','chat')),
  push_enabled boolean NOT NULL DEFAULT true,
  PRIMARY KEY (user_id, event_type)
);
CREATE TABLE devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform text NOT NULL,
  push_token text NOT NULL UNIQUE,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ride_reminders (               -- rappel H-1 déjà envoyé (un seul par personne et trajet)
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ride_id, user_id)
);

CREATE TABLE search_quota (                -- recherche manuelle limitée par jour
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  day date NOT NULL,
  count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);

CREATE TABLE reports (                     -- signalements
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES users(id),
  target_user_id uuid REFERENCES users(id),
  target_message_id uuid REFERENCES messages(id),
  reason text NOT NULL CHECK (reason IN ('dangerous_driving','inappropriate_behaviour','fake_profile','other')),
  message text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reports_reporter_idx ON reports (reporter_id, created_at);
