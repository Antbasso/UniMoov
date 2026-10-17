#!/bin/sh
# Rôle de l'API, sans superutilisateur (docs/deploiement.md) : lit et écrit les données, crée le
# schéma de la file de tâches, mais ne peut ni modifier le schéma de l'application, ni lancer de
# programme sur le serveur (COPY ... PROGRAM). Les migrations passent par le propriétaire.
# Exécuté au premier démarrage de la base ; relançable sur une base existante :
#   docker compose exec db sh /docker-entrypoint-initdb.d/10-app-role.sh
set -eu
: "${APP_DB_PASSWORD:?définis APP_DB_PASSWORD dans .env}"
APP_DB_USER="${APP_DB_USER:-unimoov_app}"

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -v app_user="$APP_DB_USER" -v app_password="$APP_DB_PASSWORD" -v owner="$POSTGRES_USER" -v db="$POSTGRES_DB" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'app_user', :'app_password') \gexec
-- CREATE sur la base : pg-boss crée son propre schéma au démarrage.
GRANT CONNECT, CREATE ON DATABASE :"db" TO :"app_user";
GRANT USAGE ON SCHEMA public TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"app_user";
-- Tables créées plus tard par les migrations du propriétaire.
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"app_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"owner" IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO :"app_user";
-- Base déjà utilisée par le propriétaire : la file de tâches lui est rendue.
SELECT format('ALTER SCHEMA pgboss OWNER TO %I', :'app_user')
WHERE EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'pgboss') \gexec
SELECT format('ALTER TABLE pgboss.%I OWNER TO %I', tablename, :'app_user')
FROM pg_tables WHERE schemaname = 'pgboss' \gexec
SQL
echo "rôle $APP_DB_USER prêt"
