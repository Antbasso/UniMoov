-- Réactions : n'importe quel emoji (choix complet comme au clavier), plus seulement six. Le
-- serveur vérifie que c'est bien un emoji (validation Zod) ; ici, juste une longueur bornée.
ALTER TABLE message_reactions DROP CONSTRAINT message_reactions_emoji_check;
ALTER TABLE message_reactions ADD CONSTRAINT message_reactions_emoji_check CHECK (char_length(emoji) BETWEEN 1 AND 16);
