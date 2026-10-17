-- Audit de sécurité (docs/decisions.md, 2026-10-17).

-- Échecs de connexion : par adresse et IP hachée (blocage court) et par adresse sur la journée
-- (seuil plus haut, contre une attaque répartie sur beaucoup d'IP). Purgés chaque nuit.
CREATE TABLE login_failures (
  email text PRIMARY KEY,                 -- clé : « adresse|IP hachée » ou « adresse|jour »
  failures integer NOT NULL DEFAULT 0,
  window_start timestamptz NOT NULL,
  locked_until timestamptz
);

-- Place demandée par un passager (recherche, « voir d'autres ») : le conducteur doit l'accepter
-- avant que nom et adresse soient échangés (cahier §4, acceptation des deux parties).
ALTER TYPE participant_status ADD VALUE IF NOT EXISTS 'requested' BEFORE 'accepted';

INSERT INTO app_settings (key, value) VALUES
  ('auth.loginMaxFailures', '10'),
  ('auth.loginLockMinutes', '15'),
  ('auth.loginDailyMaxFailures', '100'),
  ('auth.signupCodesPerDay', '10')
ON CONFLICT (key) DO NOTHING;

-- Paiement à l'arrivée (décision de l'équipe du 17/10/2026) : chaque passager termine son
-- trajet (arrivé à destination, ou sorti avant) ; le prix final est calculé à la clôture.
ALTER TABLE ride_participants
  ADD COLUMN arrived_at timestamptz,
  ADD COLUMN ended_at timestamptz;

-- Retrait vers un IBAN : seul le prestataire garde l'IBAN ; ici, les 4 derniers caractères.
ALTER TABLE payouts ADD COLUMN iban_last4 text;
