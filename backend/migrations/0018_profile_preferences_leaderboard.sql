-- Profil public façon covoiturage : mini-bio et préférences de trajet (discussion, musique,
-- cigarette, animaux), toutes facultatives. Classement du campus : prénom et photo montrés
-- seulement si la personne l'accepte (sinon « Un étudiant », sans photo).
ALTER TABLE users ADD COLUMN bio text CHECK (char_length(bio) <= 200);
ALTER TABLE users ADD COLUMN pref_chat text CHECK (pref_chat IN ('chatty', 'depends', 'quiet'));
ALTER TABLE users ADD COLUMN pref_music text CHECK (pref_music IN ('yes', 'depends', 'no'));
ALTER TABLE users ADD COLUMN pref_smoking text CHECK (pref_smoking IN ('ok', 'outside', 'no'));
ALTER TABLE users ADD COLUMN pref_pets text CHECK (pref_pets IN ('yes', 'some', 'no'));
ALTER TABLE users ADD COLUMN leaderboard_visible boolean NOT NULL DEFAULT false;
