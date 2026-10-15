# Contrainte de coût (coût de développement et de fonctionnement)

Projet étudiant, commission limitée : **l'objectif est de rester sous environ 10 € par mois en fonctionnement pour le pilote d'Annecy**, hors frais uniques des boutiques d'applications. Cette contrainte prime sur le confort technique. Les prix ci-dessous sont des ordres de grandeur à vérifier avant tout engagement.

## Principes
1. **Un seul serveur** (monolithe) sur un petit VPS ; pas de microservices, pas de Kubernetes, pas de Redis, pas de service managé payant.
2. **Services gratuits ou à palier gratuit généreux**, toujours derrière une interface (`MapTileProvider`, `RoutingProvider`, `GeocodingProvider`, `MailProvider`, `PaymentProvider`) pour changer de fournisseur sans réécrire.
3. **Appels externes payants au strict minimum** : filtrer avec PostGIS et des estimations locales avant d'appeler l'API d'itinéraires, mettre en cache, ne jamais appeler un service tiers depuis le mobile avec une clé embarquée.
4. **Moins de fonctionnalités, mieux faites** : tout ce qui coûte du temps de développement ou de l'argent sans être indispensable au pilote est reporté en v1.1.
5. **Mesurer** : chaque service externe a un compteur de consommation et une alerte à 80 % du quota gratuit.

## Choix retenus
| Besoin | Choix économique | Coût indicatif |
|---|---|---|
| Hébergement API + base | 1 VPS (2 vCPU, 4 Go) avec Docker Compose : API, PostgreSQL + PostGIS, Caddy (HTTPS automatique) | 4 à 6 €/mois |
| Sauvegardes | `pg_dump` quotidien chiffré vers un stockage objet à palier gratuit (ex. Cloudflare R2, 10 Go gratuits) | 0 € |
| Fond de carte | Données OpenStreetMap, fichier **PMTiles** de la région (Haute-Savoie / Auvergne-Rhône-Alpes) servi en statique depuis le stockage objet, affiché par `flutter_map` + `flutter_map_pmtiles`. Pas de serveur de tuiles, pas de quota | 0 € |
| Géocodage d'adresses | API publique **Base Adresse Nationale** (adresse.data.gouv.fr / Géoplateforme), gratuite pour la France ; résultats mis en cache | 0 € |
| Itinéraires, détours, ETA | Palier gratuit d'**OpenRouteService** au départ (quotas quotidiens) derrière `RoutingProvider` ; plan B : **OSRM ou Valhalla auto-hébergé** avec l'extrait OSM de la région sur le même VPS | 0 € |
| Notifications push | Firebase Cloud Messaging | 0 € |
| E-mail (code de confirmation) | Palier gratuit d'un service transactionnel (Brevo, Resend…) ; quelques centaines d'e-mails par jour suffisent | 0 € |
| Photos de profil | Redimensionnées à 256 px côté serveur, stockage objet ; initiales par défaut | ~0 € |
| Suivi des erreurs | Palier gratuit de Sentry ; supervision par un ping gratuit (UptimeRobot) | 0 € |
| CI | GitHub Actions (minutes gratuites) | 0 € |
| Nom de domaine | un `.fr` ou `.app` | ~10 à 15 €/an |
| Google Play | compte développeur | ~25 € une fois |
| App Store | compte Apple Developer | ~99 €/an, **peut être pris en charge par l'université ou une association** ; sinon lancer d'abord sur Android |

Total de fonctionnement visé : environ 5 à 7 €/mois, plus les frais uniques ci-dessus.

## Ce qui est reporté en v1.1 pour économiser du temps et de l'argent
- Connexion Google/Apple (l'e-mail universitaire + mot de passe suffit) : évite deux intégrations et la revue des comptes OAuth.
- Agenda Google Calendar et Microsoft Graph (vérification des applications OAuth, consentement administrateur de l'université) : le pilote utilise le **lien ICS** (les universités publient en général un lien ICS) et la saisie manuelle.
- Paiement intégré (voir ci-dessous).
- Pièces jointes dans le chat : messages texte uniquement.
- Messagerie en groupes personnalisés si le temps manque (les messages privés et le chat de trajet restent en v1).

## Paiement : la décision qui pèse le plus sur l'économie du projet
Un prestataire de paiement prélève un fixe par transaction (de l'ordre de 0,25 € en plus d'un pourcentage). Sur un trajet étudiant de 2 à 4 €, cela peut représenter 10 % du montant, soit plus que la commission prévue. Encaisser de l'argent pour le compte d'autres personnes peut aussi imposer de passer par un prestataire agréé.

**Choix pour le pilote** : l'app calcule le montant exact dû par chaque passager à la validation de sa présence (cahier §5), l'affiche, tient un **registre des sommes dues**, et le passager règle hors de l'app (espèces ou application de paiement de son choix, avec ouverture directe de l'application si possible) ; le conducteur confirme la réception. Aucun frais de transaction, aucune détention de fonds. La commission n'est alors **pas collectée** pendant le pilote : le financement vient des partenariats (cahier, modèle B2B2C). `PaymentProvider` permet d'ajouter plus tard un portefeuille rechargeable (un seul prélèvement par recharge, donc un seul frais fixe pour plusieurs trajets).

Cette décision change le cahier §5 pour la v1 ; elle est à valider par l'équipe (voir `docs/decisions.md`).

## Règles de conception pour limiter les coûts
- **Itinéraires** : (1) présélection SQL avec `ST_DWithin` autour de la route de base du conducteur, (2) estimation du détour par distance à vol d'oiseau × 1,3, (3) appel à l'API uniquement pour les 3 à 5 meilleurs candidats, (4) cache des itinéraires par coordonnées arrondies (~100 m) et créneau, (5) tracé des arrêts calculé une seule fois à la confirmation et recalculé seulement si les arrêts changent.
- **ETA en direct** : calculé sur le serveur à partir de la position reçue et du tracé déjà connu (distance restante ÷ vitesse moyenne récente). Nouvel appel d'itinéraire seulement si le conducteur s'écarte du tracé de plus de 200 m, au plus une fois par minute.
- **Suivi en direct** : un seul WebSocket par participant, uniquement pendant un trajet `in_progress` ; position envoyée toutes les 5 s en mouvement et toutes les 20 s à l'arrêt ; dernière position gardée **en mémoire** ; trace stockée toutes les 30 s seulement, supprimée après 7 jours (réglable).
- **Base de données** : index GiST sur les géométries, purge planifiée des données expirées (chats archivés, traces, codes), pas de stockage d'événements d'agenda bruts.
- **Mobile** : les clés d'API tierces restent sur le serveur ; fond de carte PMTiles mis en cache sur l'appareil ; pas de polling (WebSocket et push).
- **Développement** : pas de génération de code ni de dépendance superflue ; un seul langage côté serveur ; composants Flutter réutilisés ; tests ciblés sur la logique métier (matching, prix, score, liens GPS, droits d'accès) plutôt qu'une couverture exhaustive.
