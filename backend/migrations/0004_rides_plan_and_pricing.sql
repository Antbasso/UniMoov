-- M3 : plan des trajets confirmés (tracé, arrêts, heures de passage) et prix estimé.

-- Tracé estimé (lignes droites) quand le fournisseur d'itinéraires est indisponible.
ALTER TABLE rides ADD COLUMN route_estimated boolean NOT NULL DEFAULT false;
-- Moment du dernier calcul du plan (null : à calculer).
ALTER TABLE rides ADD COLUMN planned_at timestamptz;

INSERT INTO app_settings (key, value) VALUES
  -- Distance maximale entre le domicile et un point de rendez-vous choisi par le passager.
  ('rides.meetingPointMaxMeters', '2000')
ON CONFLICT (key) DO NOTHING;
