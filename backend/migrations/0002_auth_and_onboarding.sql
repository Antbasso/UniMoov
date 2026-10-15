-- M1 : inscription par code, jetons de rafraîchissement, onboarding, un véhicule par utilisateur.

-- Codes de confirmation : stockés hachés (HMAC), usage unique, durée courte, essais limités.
CREATE TABLE verification_codes (
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

-- Jetons de rafraîchissement rotatifs : seul le hash est stocké ; une famille par connexion,
-- révoquée entièrement si un jeton déjà utilisé est présenté (vol présumé).
CREATE TABLE refresh_tokens (
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

-- État des étapes d'onboarding : { "<étape>": "done" | "skipped" }.
ALTER TABLE users ADD COLUMN onboarding_steps jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Un seul véhicule par utilisateur (PUT /me/vehicle).
CREATE UNIQUE INDEX vehicles_user_id_key ON vehicles (user_id);

CREATE INDEX pauses_user_idx ON pauses (user_id);

INSERT INTO app_settings (key, value) VALUES
  ('auth.allowedEmailDomains', '["univ-smb.fr", "etu.univ-smb.fr"]')
ON CONFLICT (key) DO NOTHING;
