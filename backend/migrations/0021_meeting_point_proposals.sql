-- Point de rencontre proposé par le conducteur à un passager (avant ou après acceptation) ; le
-- passager l'accepte (il devient son point de rendez-vous) ou le refuse (effacé).
ALTER TABLE ride_participants
  ADD COLUMN proposed_pickup_label text,
  ADD COLUMN proposed_pickup_location geography(Point, 4326);
