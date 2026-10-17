-- M6 : messagerie (privée, groupes, chat de trajet), notifications push, rappel H-1.

-- Une conversation de trajet par trajet ; une conversation privée par paire (clé triée).
CREATE UNIQUE INDEX conversations_ride_idx ON conversations (ride_id) WHERE kind = 'ride';
ALTER TABLE conversations ADD COLUMN direct_key text;
CREATE UNIQUE INDEX conversations_direct_idx ON conversations (direct_key) WHERE kind = 'direct';
ALTER TABLE conversations ADD COLUMN created_by uuid REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE conversations ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE conversations ADD COLUMN last_message_at timestamptz;
CREATE INDEX conversations_retention_idx ON conversations (delete_after) WHERE delete_after IS NOT NULL;

-- Lu jusqu'à : compte des messages non lus.
ALTER TABLE conversation_members ADD COLUMN last_read_at timestamptz;
ALTER TABLE conversation_members ADD COLUMN joined_at timestamptz NOT NULL DEFAULT now();
CREATE INDEX conversation_members_user_idx ON conversation_members (user_id);
ALTER TABLE messages ADD CONSTRAINT messages_body_length CHECK (char_length(body) BETWEEN 1 AND 2000);

-- Préférences par catégorie d'événement (cahier §11) ; absence de ligne = activé.
ALTER TABLE notification_preferences ADD CONSTRAINT notification_preferences_event_check
  CHECK (event_type IN ('match', 'ride_update', 'ride_reminder', 'chat'));
ALTER TABLE notification_preferences ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE devices ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
CREATE INDEX devices_user_idx ON devices (user_id);

-- Rappels déjà envoyés : un seul rappel par personne et par trajet.
CREATE TABLE ride_reminders (
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ride_id, user_id)
);

INSERT INTO app_settings (key, value) VALUES
  -- Chat de trajet : lecture seule tant de jours après la fin (ou l'annulation), puis supprimé.
  ('chat.rideArchiveDays', '7'),
  ('chat.rideDeleteDays', '30'),
  ('chat.maxGroupMembers', '10'),
  -- Rappel de trajet : tant de minutes avant le départ (cahier §11 : 1 heure).
  ('notifications.reminderMinutes', '60')
ON CONFLICT (key) DO NOTHING;
