-- M2 : emploi du temps (lien ICS chiffré, saisie manuelle), propositions et matching.

-- Une seule connexion d'agenda par utilisateur ; le lien ICS (secret) est chiffré.
CREATE UNIQUE INDEX calendar_connections_user_key ON calendar_connections (user_id);
ALTER TABLE calendar_connections ADD COLUMN last_error text;

-- Semaine type saisie à la main (secours sans agenda) : jour ISO 1 = lundi.
CREATE TABLE manual_schedule_days (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_time time NOT NULL,
  end_time time NOT NULL CHECK (end_time > start_time),
  PRIMARY KEY (user_id, weekday)
);

-- Un créneau par jour et par source (début et fin de journée seulement).
ALTER TABLE schedule_slots DROP CONSTRAINT schedule_slots_user_id_start_at_key;
ALTER TABLE schedule_slots ADD CONSTRAINT schedule_slots_user_day_source_key UNIQUE (user_id, day, source);
CREATE INDEX schedule_slots_day_idx ON schedule_slots (day);

-- Jour du trajet (fuseau de Paris) pour regrouper les propositions.
ALTER TABLE rides ADD COLUMN day date;
CREATE INDEX rides_day_direction_idx ON rides (day, direction);
CREATE INDEX ride_participants_user_idx ON ride_participants (user_id);

-- Refus mémorisés : le matching ne repropose pas la même paire ce jour-là.
CREATE TABLE proposal_declines (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  other_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day date NOT NULL,
  direction text NOT NULL CHECK (direction IN ('to_campus','from_campus')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, other_user_id, day, direction)
);

-- Semaines déjà générées (la génération hebdomadaire n'est faite qu'une fois).
CREATE TABLE matching_runs (
  week text PRIMARY KEY,
  generated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO app_settings (key, value) VALUES
  ('matching.roadFactor', '1.3'),
  ('matching.avgSpeedKmh', '40'),
  ('matching.arrivalWindowMinutes', '30'),
  ('calendar.horizonDays', '28')
ON CONFLICT (key) DO NOTHING;
