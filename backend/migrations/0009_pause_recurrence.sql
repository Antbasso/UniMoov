-- Pauses comme des événements d'agenda (cahier §12) : la première occurrence va de starts_on
-- à ends_on ; recurrence la répète jusqu'à repeat_until.
--   'weekly:N'  : toutes les N semaines (1 à 8)
--   'monthly:N' : tous les N mois (1 à 6), même jour du mois
--   'days:1,3'  : chaque semaine, les jours ISO donnés (1 = lundi)
ALTER TABLE pauses ADD COLUMN repeat_until date;

-- Ancien format « une semaine sur N » sur toute la plage : première occurrence = la semaine
-- de début (jusqu'au dimanche), répétée jusqu'à l'ancienne fin.
UPDATE pauses
SET repeat_until = ends_on,
    ends_on = LEAST(ends_on, starts_on + (7 - EXTRACT(ISODOW FROM starts_on)::int))
WHERE recurrence LIKE 'weekly:%';

ALTER TABLE pauses ADD CONSTRAINT pauses_repeat_until_check
  CHECK ((recurrence IS NULL) = (repeat_until IS NULL) AND (repeat_until IS NULL OR repeat_until >= ends_on));
