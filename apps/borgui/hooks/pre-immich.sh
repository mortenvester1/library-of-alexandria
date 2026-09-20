#!/usr/bin/env bash
# Immich: dump Postgres to /local/dumps, leaving the stack running.
# Per https://docs.immich.app/administration/backup-and-restore — pg_dump of the
# single database, not pg_dumpall.
set -euo pipefail

container="${IMMICH_DB_CONTAINER:-immich_postgres}"
db="${IMMICH_DB_NAME:?set IMMICH_DB_NAME}"
user="${IMMICH_DB_USER:?set IMMICH_DB_USER}"
out=/local/dumps/immich

mkdir -p "$out"

# No `docker exec -t`: a TTY mangles the byte stream, which silently corrupts the
# gzip. Upstream's snippet has it; it is wrong for a redirected dump.
# Write to .tmp and rename, so an aborted dump never leaves a truncated file for
# Borg to archive as if it were good.
docker exec "$container" \
  pg_dump --clean --if-exists --dbname="$db" --username="$user" \
  | gzip > "$out/immich.sql.gz.tmp"

mv "$out/immich.sql.gz.tmp" "$out/immich.sql.gz"
