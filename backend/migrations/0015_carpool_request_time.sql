-- Demande de covoiturage avec une heure (« je cherche un trajet jeudi vers 8 h »).
ALTER TABLE messages ADD COLUMN carpool_time timestamptz;
