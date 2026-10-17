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
# L'API redémarre quoi qu'il arrive ; les objets de l'extension PostGIS donnent des avertissements
# sans gravité à la restauration, d'où la vérification explicite plutôt que l'arrêt au premier.
trap 'docker compose start api' EXIT
set +e
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass file:secrets/backup-passphrase -in "$1" \
  | docker compose exec -T db pg_restore -U "${POSTGRES_USER:-unimoov}" -d "${POSTGRES_DB:-unimoov}" --clean --if-exists --no-owner
status=("${PIPESTATUS[@]}")
set -e
[ "${status[0]}" -eq 0 ] || { echo "déchiffrement impossible (phrase de passe ou fichier)" >&2; exit 1; }
[ "${status[1]}" -eq 0 ] || echo "pg_restore a signalé des avertissements (code ${status[1]}) : vérifie les journaux ci-dessus" >&2
docker compose exec -T db psql -U "${POSTGRES_USER:-unimoov}" -d "${POSTGRES_DB:-unimoov}" -Atc 'SELECT count(*) FROM users' >/dev/null
echo "restauration terminée"
