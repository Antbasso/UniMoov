-- Répondre à un message : la réponse cite le message d'origine (repris en petit au-dessus). Le
-- message cité supprimé (rétention), la réponse reste, sans citation.
ALTER TABLE messages ADD COLUMN reply_to_id uuid REFERENCES messages(id) ON DELETE SET NULL;
