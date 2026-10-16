-- M4 : départ, présence, clôture, portefeuille (registre en écriture seule), suivi en direct.

-- Registre en écriture seule, garanti par la base : aucune écriture modifiée ni supprimée.
CREATE FUNCTION wallet_ledger_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'wallet_ledger est en écriture seule';
END;
$$;
CREATE TRIGGER wallet_ledger_no_update BEFORE UPDATE OR DELETE ON wallet_ledger
  FOR EACH ROW EXECUTE FUNCTION wallet_ledger_append_only();
CREATE INDEX wallet_ledger_operation_idx ON wallet_ledger (operation_id);

-- Montant retenu au départ pour ce passager (libéré au paiement ou à la clôture).
ALTER TABLE payments ADD COLUMN held_cents integer NOT NULL DEFAULT 0 CHECK (held_cents >= 0);
ALTER TABLE payments ADD COLUMN paid_at timestamptz;

CREATE INDEX position_trace_recorded_idx ON position_trace (recorded_at);

INSERT INTO app_settings (key, value) VALUES
  -- Arrivée détectée quand le conducteur est à moins de ce rayon de la destination.
  ('tracking.arrivalRadiusMeters', '200'),
  -- Départ possible à partir de ce délai avant l'heure du trajet.
  ('rides.startWindowMinutes', '120')
ON CONFLICT (key) DO NOTHING;
