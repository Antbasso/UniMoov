-- Distance parcourue à bord par chaque passager (de sa prise en charge au campus, ou du campus
-- à sa dépose), calculée avec le plan : sa part du carburant est au prorata (cahier §5).
ALTER TABLE ride_participants ADD COLUMN onboard_m integer CHECK (onboard_m >= 0);
