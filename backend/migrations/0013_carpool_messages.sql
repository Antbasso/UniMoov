-- Proposition de covoiturage dans une conversation (groupe ou privé) : un conducteur partage
-- un de ses trajets (« offer »), ou un passager cherche une voiture (« request ») ; les membres
-- l'acceptent d'un toucher. Les deux ont dit oui : le passager est accepté directement.
ALTER TABLE messages ADD COLUMN carpool_kind text CHECK (carpool_kind IN ('offer', 'request'));
ALTER TABLE messages ADD COLUMN carpool_ride_id uuid REFERENCES rides(id) ON DELETE SET NULL;
ALTER TABLE messages ADD COLUMN carpool_day date;
ALTER TABLE messages ADD COLUMN carpool_direction text CHECK (carpool_direction IN ('to_campus', 'from_campus'));

CREATE TABLE carpool_joins (            -- qui a accepté quelle proposition, et dans quelle voiture
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);
