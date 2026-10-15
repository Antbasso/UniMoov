# Journal des décisions

Une ligne par décision : `date | décision | raison`.

2026-10-15 | Cartes : flutter_map + PMTiles OSM hébergé en statique | gratuit, sans quota ni clé
2026-10-15 | Jobs asynchrones avec pg-boss | évite d'ajouter Redis en v1
2026-10-15 | Waze : navigation arrêt par arrêt | Waze n'accepte qu'une seule destination par lien
2026-10-15 | Un seul VPS Docker Compose, pas de service managé | coût de fonctionnement visé 5 à 7 €/mois
2026-10-15 | Géocodage Base Adresse Nationale, itinéraires OpenRouteService gratuit puis OSRM auto-hébergé si besoin | coût nul
2026-10-15 | V1.1 : connexion Google/Apple, agenda Google/Microsoft, pièces jointes | réduit coût et temps de dev
2026-10-15 | Paiement dans l'app via portefeuille prépayé (recharge min. 10 €, retrait groupé) chez un prestataire agréé, fournisseur factice d'abord | dilue les frais fixes par transaction, UniMoov ne détient pas les fonds. A VALIDER PAR L'EQUIPE : choix du prestataire, montants (commission, recharge min., seuil de retrait)
