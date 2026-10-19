-- Modèle et couleur du véhicule, pour que les passagers reconnaissent la voiture.
ALTER TABLE vehicles ADD COLUMN model text CHECK (char_length(model) BETWEEN 1 AND 40);
ALTER TABLE vehicles ADD COLUMN color text CHECK (char_length(color) BETWEEN 1 AND 30);
