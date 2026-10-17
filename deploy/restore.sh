#!/usr/bin/env bash
# Restauration d'une sauvegarde chiffrée (docs/deploiement.md). Écrase la base actuelle.
#   ./deploy/restore.sh backups/unimoov-20261101T031500Z.dump.enc
set -euo pipefail

cd "$(dirname "$0")/.."
[ $# -eq 1 ] && [ -f "$1" ] || { echo "usage : $0 <fichier .dump.enc>" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

read -r -p "La base ${POSTGRES_DB:-unimoov} va être remplacée. Taper OUI pour continuer : " answer
[ "$answer" = "OUI" ] || exit 1

docker compose stop api
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass file:secrets/backup-passphrase -in "$1" \
  | docker compose exec -T db pg_restore -U "${POSTGRES_USER:-unimoov}" -d "${POSTGRES_DB:-unimoov}" --clean --if-exists --no-owner
docker compose start api
echo "restauration terminée"
