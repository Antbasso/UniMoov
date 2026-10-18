-- Part du conducteur « en attente » (compte pending:<id>) pendant le délai de signalement,
-- puis versée sur son solde, sauf litige ouvert (cahier §5, décision du 18/10/2026).
ALTER TABLE wallets ADD COLUMN pending_cents integer NOT NULL DEFAULT 0;
ALTER TABLE payments ADD COLUMN released_at timestamptz;
-- Paiements déjà versés directement sur le solde : rien à libérer.
UPDATE payments SET released_at = paid_at WHERE status = 'paid';

INSERT INTO app_settings (key, value) VALUES ('wallet.releaseAfterHours', '24')
ON CONFLICT (key) DO NOTHING;
