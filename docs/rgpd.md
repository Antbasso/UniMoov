# RGPD : registre des traitements et checklist

Document de référence pour la conformité du pilote d'Annecy. Responsable du traitement : l'équipe Uni-Moov. Contact pour les droits et les questions : unimoov.support@gmail.com. Le cahier des charges (§6, §9 et règles de confidentialité de `AGENTS.md`) fixe les exigences ; ce document dit comment elles sont tenues. À relire avant chaque mise en production et à chaque nouveau traitement.

## Registre des traitements

| Traitement | Données | Finalité | Base légale | Durée de conservation |
|---|---|---|---|---|
| Compte | mail universitaire, prénom, nom, mot de passe haché (argon2), campus | inscription, connexion, réservé aux étudiants | contrat | durée du compte ; effacé à la suppression |
| Profil de trajet | adresse du domicile et coordonnées, secteur, véhicule, rôle, application GPS | calcul des trajets et des détours | contrat | durée du compte |
| Emploi du temps | début et fin de chaque journée de cours, jamais les titres ni les lieux ; lien ICS chiffré | proposer les trajets de la semaine | consentement explicite (agenda), contrat (semaine type) | créneaux passés effacés après 7 jours ; lien supprimé à la déconnexion de l'agenda |
| Trajets | participations, arrêts, heures, statuts, montants, tracé | organiser le covoiturage, historique | contrat | conservés pour la comptabilité et les litiges ; à la suppression du compte, point de prise en charge et tracé des trajets passés effacés |
| Suivi en direct | position pendant un trajet en cours uniquement, arrêtée pour un passager dès son arrivée ou sa sortie | suivi, validation de présence | contrat | dernière position en mémoire ; trace toutes les 30 s supprimée après 7 jours (`tracking.traceRetentionDays`) |
| Paiements | portefeuille, registre comptable, recharges, retraits (IBAN transmis au prestataire, jamais stocké : 4 derniers caractères seulement) | partage des frais | contrat, obligation légale (comptabilité) | registre en écriture seule, conservé (obligation comptable), rattaché à un compte anonyme après suppression |
| Confiance | notes, événements de fiabilité, litiges, signalements | sécurité et fiabilité du service | intérêt légitime | fenêtre de 180 jours pour le score ; litiges et signalements conservés, messages libres effacés à la suppression |
| Messagerie | conversations et messages | coordination des trajets | contrat | chat de trajet archivé 7 jours après le trajet, supprimé 30 jours plus tard (`chat.rideArchiveDays`, `chat.rideDeleteDays`) ; messages d'un compte supprimé effacés, sauf un message signalé, gardé sans nom comme preuve |
| Notifications | jeton de l'appareil, préférences | rappels et alertes | contrat ; autorisation du téléphone | jeton retiré à la déconnexion, à la suppression ou quand FCM le déclare périmé |
| Sécurité | codes de vérification, sessions (refresh tokens), quotas de recherche | authentification, limites d'usage | intérêt légitime | codes effacés 1 jour après expiration ; sessions à leur expiration (30 jours ; un jeton déjà utilisé est gardé jusque-là pour détecter un vol) ; quotas, créneaux et refus après 7 jours (purge de nuit) |
| Sauvegardes | copie complète de la base, chiffrée (AES-256) | reprise après incident | intérêt légitime | 14 jours (`BACKUP_KEEP_DAYS`), puis effacées ; un compte supprimé disparaît des sauvegardes au plus tard 14 jours après |

## Sous-traitants et transferts

| Service | Données transmises | Lieu |
|---|---|---|
| Hébergeur du VPS (à choisir, docs/deploiement.md) | toute la base, chiffrée au repos selon l'offre | Union européenne |
| Brevo (mails) | adresse universitaire, texte du mail (code, alerte de litige) | Union européenne |
| Firebase Cloud Messaging (Google) | jeton de l'appareil, texte court de la notification, sans adresse ni contenu de message | hors UE possible (clauses contractuelles types de Google) |
| Géoplateforme (Base Adresse Nationale) | adresse saisie, sans identité | France |
| OpenRouteService (HeiGIT) | coordonnées des arrêts d'un trajet, sans identité | Allemagne |
| Prestataire de paiement (à venir, M4b) | montants ; pour un retrait, IBAN et nom du titulaire ; à compléter au choix du prestataire | à vérifier |

## Droits des personnes

- **Accès et portabilité** : profil, « Mes données », « Exporter mes données » (`GET /me/export`, traces de position comprises) : fichier JSON avec tout ce qui concerne la personne, sans aucun secret ni donnée d'un tiers.
- **Rectification** : profil (nom, adresse, véhicule, rôle, emploi du temps, préférences).
- **Effacement** : « Supprimer mon compte » (`DELETE /me`), confirmé par le mot de passe. Refusé pendant un trajet en cours et tant que le portefeuille n'est pas vide (l'argent appartient à la personne : retrait d'abord, depuis le portefeuille vers son IBAN). Ce qui reste : trajets (sans point de prise en charge ni tracé), paiements, notes et registre, rattachés à « Ancien membre », sans nom, mail ni adresse ; un message signalé reste comme preuve, sans nom. Le compte est fermé avant la libération des trajets : ni connexion, ni recharge, ni nouvelle proposition ensuite.
- **Retrait du consentement** : déconnexion de l'agenda (lien et créneaux supprimés), notifications coupables par catégorie ou dans les réglages du téléphone.
- **Opposition, questions, réclamation** : unimoov.support@gmail.com ; réponse sous un mois. Réclamation possible auprès de la CNIL.

## Checklist

État vérifié le 17 octobre 2026 (fin de M7). Chaque ligne cochée a un test.

- [x] Avant acceptation mutuelle : prénom, photo, secteur, horaire, score et détour seulement ; filtrage côté serveur par schémas stricts ; un passager venu par la recherche n'accède au trajet qu'après l'accord du conducteur (`tests/integration/proposals.test.ts`).
- [x] Position collectée et diffusée seulement pendant un trajet en cours, aux participants, arrêtée à la clôture ; trace purgée après 7 jours (`tests/integration/live-ride.test.ts`).
- [x] Consentement explicite avant la connexion d'un agenda ; seuls début et fin de journée stockés (`tests/integration/calendar.test.ts`, `schedule_flow_test.dart`).
- [x] Journaux sans donnée personnelle : ni IP, ni en-têtes, ni paramètres d'URL, erreurs sans le détail des valeurs ; Caddy sans journal d'accès (`tests/unit/health.test.ts`, `deploy/Caddyfile`).
- [x] Aucun secret dans le dépôt : `.env`, `secrets/` et clés de compte de service ignorés par git.
- [x] Export des données (`tests/integration/account.test.ts`, `account_flow_test.dart`).
- [x] Suppression du compte avec anonymisation de l'historique (`tests/integration/account.test.ts`, `account_flow_test.dart`).
- [x] Durées de conservation appliquées par les tâches de nuit (chat, traces, codes, sessions, créneaux) (`tests/integration/chat.test.ts`, `account.test.ts`).
- [x] Mots de passe hachés (argon2), codes à usage unique et courts, plafond de codes par adresse, blocage d'une adresse après trop d'échecs de connexion, limites de débit par personne (`tests/integration/auth.test.ts`, `rate-limit.test.ts`).
- [x] Moindre privilège : en production, l'API se connecte à la base sans droits sur le schéma ni superutilisateur, et ne voit pas la phrase de passe des sauvegardes (`deploy/db-init/10-app-role.sh`, `docker-compose.prod.yml`).
- [x] Chiffrement en transit (HTTPS par Caddy, exigé par l'app publiée) et des sauvegardes (`deploy/backup.sh`) ; sur le téléphone, jetons dans le trousseau propre à l'appareil, sauvegarde Android désactivée, fichier d'export effacé après partage.
- [ ] Politique de confidentialité publiée et liée depuis l'inscription : texte à rédiger par l'équipe à partir de ce registre.
- [ ] Hébergeur choisi et contrat de sous-traitance (DPA) accepté ; idem pour Brevo et le prestataire de paiement.
- [ ] Information de l'université (DPO de l'USMB) avant le lancement du pilote.
