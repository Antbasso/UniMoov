# Déploiement du pilote

Un seul VPS en Docker Compose (docs/couts.md) : PostgreSQL/PostGIS, l'API et Caddy, qui fournit le HTTPS automatique et sert le fond de carte. Compter une heure la première fois.

## Ce qu'il faut avant de commencer

- **Un VPS** : 2 vCPU, 4 Go de mémoire, Ubuntu 24.04, dans l'Union européenne (par exemple Hetzner CX22 ou un VPS OVHcloud, environ 4 à 6 € par mois).
- **Un nom de domaine** (environ 10 € par an), avec un sous-domaine pour l'API, par exemple `api.uni-moov.fr`.
- **Un compte Brevo** (palier gratuit) : clé d'API transactionnelle et expéditeur sur ton domaine (par exemple `ne-pas-repondre@uni-moov.fr`), domaine authentifié chez Brevo (enregistrements DNS DKIM et DMARC qu'il fournit). Une adresse Gmail comme expéditeur est refusée ou classée en indésirable : les codes d'inscription n'arriveraient pas.
- **La clé du compte de service Firebase** (console Firebase, Paramètres du projet, Comptes de service).
- Facultatif : une clé OpenRouteService pour les vrais tracés, un compte Cloudflare R2 pour la copie distante des sauvegardes.

> **Point bloquant pour la production.** Avec `NODE_ENV=production`, l'API refuse de démarrer avec le portefeuille factice (`PAYMENT_PROVIDER=fake`) : aucun argent réel ne doit transiter par lui. Il faut donc avoir branché le vrai prestataire de paiement (jalon M4b) avant le lancement public. Pour une répétition avec de faux paiements, mets `NODE_ENV=development` dans `.env` (la surcharge de production le respecte ; la documentation OpenAPI est alors publique sur `/docs` : à éviter au-delà des tests).

## 1. Préparer le serveur

1. Chez l'hébergeur, crée le VPS avec ta clé SSH.
2. Chez le registraire du domaine, ajoute un enregistrement DNS `A` : `api` vers l'adresse IPv4 du VPS (et `AAAA` vers l'IPv6 s'il y en a une).
3. Connecte-toi : `ssh root@ADRESSE_DU_VPS`, puis :

```bash
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh                 # Docker et Docker Compose
adduser --disabled-password unimoov && usermod -aG docker unimoov
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw enable
su - unimoov
git clone https://github.com/Antbasso/UniMoov.git && cd UniMoov
```

## 2. Configurer

```bash
cp .env.example .env
openssl rand -base64 48        # JWT_SECRET
openssl rand -base64 32        # CALENDAR_ENCRYPTION_KEY (32 octets)
openssl rand -base64 24        # POSTGRES_PASSWORD
nano .env
```

Dans `.env` :

```
POSTGRES_PASSWORD=...
JWT_SECRET=...
CALENDAR_ENCRYPTION_KEY=...
DOMAIN=api.uni-moov.fr
ACME_EMAIL=unimoov.support@gmail.com
MAIL_PROVIDER=brevo
BREVO_API_KEY=...
MAIL_FROM=ne-pas-repondre@uni-moov.fr
PUSH_PROVIDER=fcm
FCM_SERVICE_ACCOUNT_FILE=/run/secrets/fcm-service-account.json
ROUTING_PROVIDER=ors           # ou estimate, sans clé
ORS_API_KEY=...
```

Garde une copie de `CALENDAR_ENCRYPTION_KEY` hors du serveur (gestionnaire de mots de passe) : sans elle, les liens d'agenda enregistrés deviennent illisibles.

Les secrets en fichiers vont dans `secrets/` (ignoré par git, monté en lecture seule dans l'API) :

```bash
mkdir -p secrets
# Depuis ton PC : scp unimoov-383ff-firebase-adminsdk-xxxx.json unimoov@ADRESSE:~/UniMoov/secrets/fcm-service-account.json
openssl rand -base64 32 > secrets/backup-passphrase   # copie-la aussi hors du serveur
sudo chown 1000:1000 secrets/fcm-service-account.json
chmod 600 secrets/*
```

Fond de carte (facultatif) : pose l'extrait PMTiles de la région (README) dans `tiles/annecy.pmtiles` ; Caddy le sert sur `https://DOMAIN/tiles/annecy.pmtiles`.

## 3. Démarrer

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
docker compose logs -f api caddy      # migrations appliquées, certificat obtenu
curl https://api.uni-moov.fr/health   # {"status":"ok","db":"ok"}
```

Seul Caddy est exposé (ports 80 et 443). La base et l'API restent sur le réseau interne de Docker. Caddy ne tient aucun journal d'accès.

## 4. Sauvegardes

`deploy/backup.sh` fait un `pg_dump` chiffré (AES-256, phrase de `secrets/backup-passphrase`) dans `backups/`, garde 14 jours (`BACKUP_KEEP_DAYS`) et copie sur un stockage distant si `BACKUP_REMOTE` est défini (par exemple `r2:unimoov-backups`, après `rclone config`).

```bash
crontab -e
# 15 3 * * * cd ~/UniMoov && mkdir -p backups && ./deploy/backup.sh >> backups/backup.log 2>&1
```

Un vidage interrompu ne laisse aucun fichier. Restaurer (arrête l'API, remplace la base, relance l'API même en cas d'erreur) : `./deploy/restore.sh backups/unimoov-AAAAMMJJTHHMMSSZ.dump.enc` ; des avertissements de `pg_restore` sur les objets PostGIS sont normaux. Fais un essai de restauration une fois par trimestre.

## 5. Mettre à jour, revenir en arrière

```bash
git pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

Les migrations s'appliquent au démarrage de l'API. Retour arrière : `git checkout <commit précédent>` puis la même commande ; si une migration a changé le schéma, restaure la sauvegarde de la nuit.

## 6. Surveiller

- **Disponibilité** : une sonde UptimeRobot (gratuite) sur `https://DOMAIN/health`, alerte par mail.
- **Erreurs et quotas** : `docker compose logs api | grep -E '"level":(40|50)'` ; l'API journalise une alerte à 80 % du quota d'itinéraires.
- **Disque** : `df -h` et `du -sh backups`.

## 7. Application mobile

Construire l'app pour ce serveur :

```bash
cd mobile
flutter build appbundle --dart-define=API_BASE_URL=https://api.uni-moov.fr \
  --dart-define=PMTILES_URL=https://api.uni-moov.fr/tiles/annecy.pmtiles
```

Avant la publication sur Google Play : créer une clé de signature de publication (aujourd'hui, la version release est signée avec la clé de débogage), ajouter son empreinte SHA-1 à la clé d'API Android dans Google Cloud, et activer la signature des applications par Google Play (ajouter aussi son empreinte). iOS : compte Apple Developer et clé APNs à ajouter dans Firebase.
