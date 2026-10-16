-- M5 : annulations, notes croisées, score de fiabilité, litiges, signalements.

-- « Monté » horodaté : la clôture remplace le statut par « absent » sans validation GPS,
-- l'horodatage reste pour l'arbitrage des litiges.
ALTER TABLE ride_participants ADD COLUMN picked_up_at timestamptz;

-- Entrées du score (en écriture seule, une correction est une nouvelle entrée de poids négatif).
-- kind : completed | cancel_early | cancel_medium | cancel_late | no_show | correction
ALTER TABLE reliability_events ADD CONSTRAINT reliability_events_kind_check
  CHECK (kind IN ('completed', 'cancel_early', 'cancel_medium', 'cancel_late', 'no_show', 'correction'));
CREATE INDEX reliability_events_user_idx ON reliability_events (user_id, created_at);
-- Une seule entrée de chaque sorte par personne et par trajet (rejeu sans effet double).
CREATE UNIQUE INDEX reliability_events_once_idx ON reliability_events (user_id, ride_id, kind)
  WHERE ride_id IS NOT NULL AND kind <> 'correction';
CREATE FUNCTION reliability_events_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'reliability_events est en écriture seule';
END;
$$;
CREATE TRIGGER reliability_events_no_update BEFORE UPDATE ON reliability_events
  FOR EACH ROW EXECUTE FUNCTION reliability_events_append_only();

-- Notes : étoiles seulement (pas de commentaire libre en v1, rien à modérer).
ALTER TABLE ratings ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
CREATE INDEX ratings_rated_idx ON ratings (rated_id, created_at);

-- Litiges : niveau 1 tranché automatiquement, niveau 2 transmis à l'équipe.
ALTER TABLE disputes ADD COLUMN message text;
ALTER TABLE disputes ADD COLUMN decision text NOT NULL DEFAULT 'escalated'
  CHECK (decision IN ('upheld', 'corrected', 'escalated'));
ALTER TABLE disputes ADD COLUMN escalated_at timestamptz;
ALTER TABLE disputes ADD CONSTRAINT disputes_reason_check
  CHECK (reason IN ('cancellation_penalty', 'marked_absent', 'payment', 'driver_issue', 'other'));
CREATE UNIQUE INDEX disputes_once_idx ON disputes (ride_id, opened_by, reason);

ALTER TABLE reports ADD COLUMN message text;
ALTER TABLE reports ADD CONSTRAINT reports_reason_check
  CHECK (reason IN ('dangerous_driving', 'inappropriate_behaviour', 'fake_profile', 'other'));
CREATE INDEX reports_reporter_idx ON reports (reporter_id, created_at);

INSERT INTO app_settings (key, value) VALUES
  -- Score : moyenne bayésienne partant de `prior`, comme si `priorWeight` trajets avaient eu lieu.
  ('reliability.prior', '0.8'),
  ('reliability.priorWeight', '5'),
  -- Part des notes dans le score (le reste : comportement, annulations et absences).
  ('reliability.ratingShare', '0.4'),
  -- Seules les entrées et notes de cette période comptent : le score se rétablit.
  ('reliability.windowDays', '180'),
  -- Pénalités dégressives : plus de `earlyHours` avant, moins de `lateHours` avant, entre les deux.
  ('reliability.penalties', '{"earlyHours":24,"lateHours":2,"early":0.25,"medium":0.5,"late":1,"noShow":1.5}'),
  -- Matching : secondes de détour « ajoutées » à un score nul (priorité aux bien notés).
  ('matching.reliabilityWeightSeconds', '300'),
  ('ratings.windowDays', '7'),
  ('disputes.windowDays', '14'),
  ('reports.dailyLimit', '5'),
  ('support.email', '"unimoov.support@gmail.com"')
ON CONFLICT (key) DO NOTHING;
