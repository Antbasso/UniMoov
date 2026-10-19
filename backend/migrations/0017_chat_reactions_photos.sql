-- Réactions aux messages (une par personne et par message, jeu fermé) et photos dans les
-- conversations. La photo est réduite par l'app (environ 200 Ko), gardée en base comme les photos
-- de profil, et supprimée avec son message (rétention de la conversation).
CREATE TABLE message_reactions (
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji text NOT NULL CHECK (emoji IN ('👍', '❤️', '😂', '😮', '😢', '🙏')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

ALTER TABLE messages ADD COLUMN has_photo boolean NOT NULL DEFAULT false;
ALTER TABLE messages DROP CONSTRAINT messages_body_length;
-- Une photo peut partir sans légende.
ALTER TABLE messages ADD CONSTRAINT messages_body_length
  CHECK (char_length(body) <= 2000 AND (char_length(body) >= 1 OR has_photo));

CREATE TABLE message_photos (
  message_id uuid PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png')),
  data bytea NOT NULL CHECK (octet_length(data) <= 614400)
);
