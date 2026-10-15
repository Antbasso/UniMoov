-- Valeurs par défaut des paramètres (modifiables sans déploiement, jamais codées en dur)
-- et campus pilote. ON CONFLICT DO NOTHING : ne remplace jamais une valeur réglée en production.
INSERT INTO app_settings (key, value) VALUES
  ('pricing.commissionCentsPerPassenger', '20'),
  ('pricing.fuelPriceCentsPerLitre', '180'),
  ('wallet.minTopupCents', '1000'),
  ('wallet.holdMarginPercent', '20'),
  ('wallet.minPayoutCents', '1000'),
  ('wallet.payoutMinIntervalDays', '7'),
  ('matching.defaultMaxDetourMinutes', '10'),
  ('search.dailyQuota', '20'),
  ('tracking.presenceRadiusMeters', '150'),
  ('tracking.traceRetentionDays', '7'),
  ('chat.rideArchiveAfterDays', '30'),
  ('chat.rideDeleteAfterDays', '90')
ON CONFLICT (key) DO NOTHING;

INSERT INTO campuses (id, name, location) VALUES
  ('00000000-0000-4000-8000-000000000001', 'Campus d''Annecy (USMB)',
   ST_SetSRID(ST_MakePoint(6.1580, 45.9195), 4326)::geography)
ON CONFLICT (id) DO NOTHING;
