#!/usr/bin/env bash
# Seafile: dump all three databases, then Borg takes seafile-data.
# Per https://manual.seafile.com/13.0/administration/backup_recovery/ — databases
# first, data directory second, in that order.
set -euo pipefail

container="${SEAFILE_DB_CONTAINER:-seafile-mysql}"
user="${SEAFILE_DB_USER:-root}"
password="${SEAFILE_DB_PASSWORD:?set SEAFILE_DB_PASSWORD}"
out=/local/dumps/seafile

mkdir -p "$out"

# ccnet_db: users and groups. seafile_db: library metadata. seahub_db: web
# frontend. A restore missing any one of them is not a restore.
for db in ccnet_db seafile_db seahub_db; do
  # Password via env, not -p on the argv, which is world-readable in the
  # container's process list.
  docker exec -e MYSQL_PWD="$password" "$container" \
    mariadb-dump -u"$user" --opt "$db" \
    | gzip > "$out/$db.sql.gz.tmp"
  mv "$out/$db.sql.gz.tmp" "$out/$db.sql.gz"
done
