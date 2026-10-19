-- Profil : formation, année de naissance (âge affiché, jamais la date exacte), centres d'intérêt,
-- visibles par les étudiants qui croisent la personne sur un trajet. Photo de profil gardée en
-- base (sauvegardée avec elle, aucun service de stockage en plus), servie par l'API.
ALTER TABLE users ADD COLUMN study_program text CHECK (char_length(study_program) <= 80);
ALTER TABLE users ADD COLUMN birth_year smallint CHECK (birth_year BETWEEN 1940 AND 2020);
ALTER TABLE users ADD COLUMN interests text[] NOT NULL DEFAULT '{}' CHECK (cardinality(interests) <= 6);

CREATE TABLE user_photos (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png')),
  data bytea NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
