-- Détour estimé : temps fixe par prise en charge (quitter l'axe, s'arrêter, repartir). Calé sur
-- des itinéraires réels autour d'Annecy (OSRM) : l'estimation à vol d'oiseau seule sous-estimait
-- le détour de 4 à 10 minutes pour un passager « sur la route ».
INSERT INTO app_settings (key, value) VALUES ('matching.stopPenaltySeconds', '240')
ON CONFLICT (key) DO NOTHING;
