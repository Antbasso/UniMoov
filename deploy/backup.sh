#!/usr/bin/env bash
# Sauvegarde quotidienne chiffrée de la base (docs/deploiement.md, « Sauvegardes »).
# À lancer depuis la racine du dépôt sur le VPS, par cron :
#   15 3 * * * cd ~/UniMoov && mkdir -p backups && ./deploy/backup.sh >> backups/backup.log 2>&1
# Chiffrement AES-256 avec la phrase de passe de secrets/backup-passphrase (jamais commitée).
# Copie distante facultative avec rclone si BACKUP_REMOTE est défini (ex. r2:unimoov-backups).
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
# shellcheck disable=SC1091
source .env
set +a

KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
PASSPHRASE_FILE="secrets/backup-passphrase"
[ -s "$PASSPHRASE_FILE" ] || { echo "phrase de passe absente : $PASSPHRASE_FILE" >&2; exit 1; }

mkdir -p backups
file="backups/unimoov-$(date -u +%Y%m%dT%H%M%SZ).dump.enc"
# Écrit à part puis renommé : un vidage interrompu ne laisse jamais un fichier d'apparence valide.
trap 'rm -f "$file.tmp"' EXIT

docker compose exec -T db pg_dump -U "${POSTGRES_USER:-unimoov}" -d "${POSTGRES_DB:-unimoov}" --format=custom \
  | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass "file:$PASSPHRASE_FILE" -out "$file.tmp"
chmod 600 "$file.tmp"
mv "$file.tmp" "$file"

if [ -n "${BACKUP_REMOTE:-}" ]; then
  rclone copy "$file" "$BACKUP_REMOTE"
  rclone delete --min-age "${KEEP_DAYS}d" "$BACKUP_REMOTE"
fi
find backups -name 'unimoov-*.dump.enc' -mtime +"$KEEP_DAYS" -delete
echo "$(date -u +%FT%TZ) sauvegarde $file ($(du -h "$file" | cut -f1))"
