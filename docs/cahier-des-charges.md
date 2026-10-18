# UniMoov — Cahier des charges fonctionnel

*Document de cadrage issu d'une session de brainstorming, à destination du développeur. Version pilote (v1) et pistes d'évolution (v2) clairement séparées.*

## 1. Inscription et authentification

- Vérification d'identité obligatoire à l'inscription : l'utilisateur saisit son adresse mail universitaire et reçoit un code de confirmation par mail.
- Une fois vérifié, choix de la méthode de connexion au quotidien : identifiant (mail universitaire) + mot de passe, ou connexion rapide via Google ou Apple, reliée au compte déjà vérifié *(reporté en v1.1 pour limiter les coûts, voir `docs/couts.md`)*.
- Onboarding en plusieurs étapes, chacune avec un bouton « passer / configurer plus tard » : profil (adresse domicile, lieu de cours), véhicule si applicable, connexion de l'emploi du temps, validation des préférences de trajet pour la semaine.
- Tant que le profil n'est pas complet, l'utilisateur a accès à un mode découverte limité, sans accès au matching complet.

## 2. Profil véhicule et rôle conducteur/passager

- À la configuration du profil, l'utilisateur indique s'il possède une voiture ; si oui, consommation du véhicule et nombre de places passagers par défaut.
- La capacité par défaut peut être modifiée ponctuellement pour un trajet donné.
- Gestion du rôle à chaque trajet, deux modes au choix : mode automatique (uniquement si véhicule déclaré, l'app propose conducteur ou passager selon les besoins du secteur ; entre plusieurs conducteurs possibles, elle alterne : celui qui a le moins conduit ces dernières semaines prend le volant ; un « i » l'explique dans les réglages), ou mode forcé (l'utilisateur impose toujours conducteur ou toujours passager).
- Sans véhicule déclaré : rôle passager par défaut, pas d'accès au mode automatique.

## 3. Emploi du temps et génération des trajets

- Synchronisation d'agenda via lien ICS/CalDAV en v1 (Google Calendar et Microsoft Graph reportés en v1.1 pour limiter les coûts, voir `docs/couts.md`) ; alternative si refus : saisie manuelle des heures de début/fin de journée.
- Chaque semaine, l'appli propose automatiquement un trajet par créneau à partir de l'emploi du temps synchronisé ; l'utilisateur accepte ou refuse, avec un bouton pour voir d'autres propositions compatibles.
- Si l'agenda synchronisé modifie l'heure de début/fin d'une journée, le système relance automatiquement une nouvelle recherche de matching pour ce créneau.

## 4. Matching et recherche manuelle

- Chaque conducteur définit un seuil de détour acceptable (temps ou distance) ; le moteur ne propose un passager que si le détour reste sous ce seuil.
- V1 : règle simple de départage en cas de conflit sur les places (détour le plus court, combiné au score de fiabilité). V2 (évolution) : matching global optimisant l'ensemble du réseau.
- Recherche manuelle en secours si aucune proposition automatique : écran liste avec filtres (horaires, distance), limité en nombre de requêtes par jour pour éviter le scraping.
- Confidentialité avant acceptation mutuelle : seules ces informations sont visibles — prénom, photo, secteur de départ approximatif (jamais l'adresse exacte), horaire, score de fiabilité, temps de détour exact engendré pour le conducteur. Nom complet et adresse précise débloqués après acceptation des deux parties. Ouvrir un trajet montre d'abord la carte : le tracé du conducteur et chaque personne proposée dans sa zone, comme une annonce immobilière (un cercle d'environ 750 m qui contient le domicile sans le révéler), en provisoire tant qu'elle n'a pas accepté, puis validée ; la liste des personnes est dessous (prénom, note ★ sur 5, détour ⏱), celles qui ont refusé disparaissent. Le détour affiché est toujours celui du conducteur : côté passager, « il fait X min de détour pour toi ».
- Sur l'écran de sélection des covoitureurs, uniquement visible par le conducteur : suggestion d'ajout de passagers supplémentaires (y compris ceux écartés automatiquement car hors seuil de détour), avec simulation en direct de la baisse de prix induite.

## 5. Tarification

- Estimation du coût du trajet : consommation du véhicule × distance du trajet × prix moyen du carburant en France (actualisé). Partage au prorata de la distance : le coût de chaque portion de route est divisé entre les personnes à bord sur cette portion (conducteur inclus). Un passager pris au milieu du trajet ne paie que la portion qu'il fait, de sa prise en charge jusqu'au campus (ou du campus jusqu'à sa dépose au retour). Seul passager sur tout le trajet, il paie la moitié du coût.
- Commission UniMoov : petite commission symbolique par passager, valeur à définir dans le business model — implémenter comme variable configurable avec une valeur par défaut, ne pas coder en dur.
- Le prix affiché avant le trajet est une estimation (basée sur le nombre de passagers prévus). Le prix définitif n'est calculé qu'à la toute fin, à la clôture du trajet : même partage au prorata, entre les seules personnes réellement présentes (conducteur et passagers dont la présence a été validée). Un passager absent ne fait donc pas payer plus cher les autres ; il est pénalisé sur son score (section 7), pas eux.
- Le conducteur avance les frais ; chaque passager pris en charge (présence validée) le rembourse via l'app à la clôture, qu'il soit descendu à la destination prévue ou ailleurs (changement de destination, accord avec le conducteur), comme sur les autres services de covoiturage. Le conducteur ne touche rien pour un passager sans validation de présence. La part du conducteur est versée sur son solde 24 h après le paiement (configurable), sauf si un problème est signalé pendant ce délai : elle reste alors bloquée jusqu'à la décision de l'équipe. *Pour limiter les frais de transaction, le paiement passe par un portefeuille prépayé dans l'app (voir ci-dessous).*
- Portefeuille prépayé (v1) : le passager recharge son portefeuille dans l'app (montant minimum configurable, par défaut 10 €) ; au paiement d'un trajet, la somme est prélevée sur le solde, sans nouveau frais de transaction. Impossible de réserver un trajet (accepter une proposition, demander une place) si le solde ne couvre pas le prix maximal de ce trajet (celui d'un trajet à deux, conducteur compris) : une fenêtre l'explique et propose de recharger. Au départ, ce prix maximal est retenu sur le solde ; un passager dont le solde ne suffit plus au départ perd sa place et en est prévenu. À la clôture, seul le prix définitif est prélevé, le reste est libéré. Les sommes dues au conducteur, comme tout solde, se retirent vers un compte bancaire en saisissant son IBAN, à partir d'un seuil configurable (par défaut 10 €) et au plus une fois par semaine. Le portefeuille est tenu par un prestataire de paiement agréé, pas par UniMoov. La commission est ajoutée au prix payé par le passager et prélevée au paiement.
- V2 (évolution) : QR code pour l'accès aux places réservées.

## 6. Messagerie intégrée

Architecture façon Teams, trois niveaux de conversation :

- Message privé en tête-à-tête entre deux utilisateurs.
- Groupe personnalisé créé librement par les utilisateurs (trajets récurrents).
- Chat automatique lié à un trajet confirmé, incluant tous les participants, créé à la confirmation et lié au cycle de vie du trajet.
- Rétention : le chat de trajet reste accessible un certain temps après la fin du trajet, puis est archivé, puis supprimé (durée exacte à définir — cohérent avec la minimisation des données RGPD).

## 7. Confiance et fiabilité

- Notation croisée optionnelle après chaque trajet : le conducteur note ses passagers, les passagers notent le conducteur.
- Score de fiabilité agrégeant les notations et des données comportementales objectives (taux d'annulation, etc.), visible publiquement sur le profil avant tout engagement sur un trajet.
- Le score est utilisé comme critère dans le matching automatique (priorité aux utilisateurs bien notés) — pas de sanction brutale ni de bannissement automatique.

## 8. Annulations et modifications

- Toute annulation entraîne : une pénalité sur le score de fiabilité (dégressive selon le délai, plus sévère si tardif), une notification immédiate à l'autre partie, et une relance automatique de recherche de remplaçant sur le créneau.
- Un changement d'horaire détecté dans l'agenda synchronisé déclenche aussi une nouvelle recherche automatique (voir section 3).

## 9. Validation de présence et clôture du trajet

- Au moment du rendez-vous, vérification de la géolocalisation des deux téléphones pour confirmer leur proximité physique ; cette validation confirme la présence du passager (le paiement n'a lieu qu'à la clôture, voir section 5).
- Échec de la vérification pour un passager = absence constatée automatiquement → il ne paie pas sa part, pénalité de score (section 8).
- Nécessite un partage de localisation actif en continu pendant tout le trajet (bien expliciter à l'utilisateur côté confidentialité).
- Arrivée : chaque passager est marqué arrivé quand son téléphone, ou celui du conducteur, atteint sa destination ; son suivi s'arrête alors.
- Clôture : chacun peut terminer. Un passager à bord qui termine avant la destination prévue est averti que sa part reste due ; le conducteur est notifié tout de suite. En cas de problème (trajet écourté contre son gré, comportement), chacun peut le signaler dans les 24 h : le paiement reste bloqué jusqu'à la décision de l'équipe. Un passager pas encore pris en charge ne peut pas « terminer » : il annule sa place (pénalité). Clôture automatique quand tous les passagers ont terminé, quand le conducteur arrive à destination, ou au bout d'un délai configurable (`rides.staleAfterHours`).

## 10. Litiges

- Premier niveau : arbitrage automatique basé sur les horodatages serveur (annulation, confirmation de présence, etc.).
- Second niveau : en cas de désaccord, possibilité de contacter l'équipe UniMoov par mail ou message pour un arbitrage humain.

## 11. Notifications

- Push activé par défaut pour tous les événements (nouveau match, rappel de trajet, annulation, message de chat, etc.). Rappel de trajet : 1 heure avant le départ.
- Personnalisation fine disponible dans les paramètres (ex. désactiver les notifications de chat en gardant les rappels de trajet).

## 12. Mode pause

- Bouton de mise en pause visible directement sur l'écran principal (pas enfoui dans les paramètres).
- La pause n'affecte pas le score de fiabilité.
- Programmable à l'avance comme un événement d'agenda : des dates (du … au …), certains jours chaque semaine (ex. tous les lundis) jusqu'à une date, ou une période qui se répète (toutes les N semaines, tous les N mois, par exemple pour l'alternance) jusqu'à une date.

## 13. Plateforme

- Application mobile uniquement (iOS/Android via Flutter), pas de version web — positionnement proche de BlaBlaCar Daily (covoiturage courte distance et récurrent domicile-campus), à l'opposé d'un covoiturage longue distance occasionnel.

## 14. Carte et suivi en direct

- Carte du trajet, affichée directement en ouvrant le trajet (un seul écran, sans clic de plus) : le tracé de l'itinéraire du conducteur, son point de départ, la destination (campus) et un repère pour chaque passager (adresse ou point de rendez-vous), dans l'ordre de ramassage, avec l'heure de passage estimée à chaque arrêt. Pour un passager, le départ du conducteur reste toujours approximatif (sa zone, le tracé sans ses abords). Le chat du trajet est une icône en haut ; une fois le trajet terminé, la notation passe en tête et le reste se replie. Les trajets terminés quittent l'accueil pour l'historique du profil.
- Confidentialité : un passager n'apparaît avec son adresse exacte qu'après acceptation mutuelle (voir section 4) ; avant cela, seul le secteur approximatif est montré. Chaque participant ne voit sur la carte que les personnes de son propre trajet.
- Point de rendez-vous : le passager peut remplacer son adresse par un point de rendez-vous (par exemple un arrêt proche) ; c'est ce point qui est affiché au conducteur à la place de l'adresse.
- Suivi en direct pendant le trajet : le passager voit la position du conducteur se déplacer en temps réel vers son point de ramassage (heure d'arrivée estimée mise à jour) ; le conducteur voit les passagers pas encore montés. Le partage s'active au départ du trajet et s'arrête à sa clôture (voir section 9) ; il ne fonctionne jamais en dehors d'un trajet confirmé.
- Si la position d'un participant n'est plus reçue, la carte affiche « dernière position connue » avec l'heure, sans bloquer le trajet.

## 15. Lancement de la navigation GPS externe

- Au moment du départ, le conducteur ouvre le trajet déjà programmé : liste ordonnée des arrêts (adresse ou point de rendez-vous de chaque passager, puis destination).
- Bouton « Lancer la navigation » : l'app propose les applications GPS installées sur le téléphone (Google Maps, Waze, Apple Plans, et autres si disponibles) ; le choix est mémorisé comme application par défaut, modifiable dans les paramètres.
- L'itinéraire est transmis à l'application choisie avec tous les arrêts quand elle le permet (Google Maps, Apple Plans). Waze n'accepte qu'une destination : l'app lance alors la navigation arrêt par arrêt, avec un bouton « Arrêt suivant » qui relance Waze vers le point suivant.
- L'app UniMoov reste utilisable pendant la navigation : le partage de position continue en arrière-plan, et le conducteur peut marquer chaque passager comme « monté ».
- Si l'ordre des arrêts change (passager retiré, annulation), l'ordre est recalculé et le conducteur est notifié.

## 16. Points encore ouverts à trancher plus tard

- Montant exact de la commission UniMoov (dépend du business model final).
- Durée exacte de rétention des chats de trajet avant archivage/suppression.
- Fournisseur de cartes et d'itinéraires (coût, quotas) et fréquence d'envoi de la position en direct.
- Détail du matching global v2 (optimisation réseau) et du système de QR code v2.
