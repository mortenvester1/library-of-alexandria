#!/usr/bin/env bash
# Prerequisites for apps/immich: the two host directories and the shared
# monitoring network.
#
# Dry run by default:
#   sudo ./setup.sh
#   sudo ./setup.sh --apply
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a
: "${UPLOAD_LOCATION:?set UPLOAD_LOCATION in .env}"
: "${DB_DATA_LOCATION:?set DB_DATA_LOCATION in .env}"

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
(( APPLY )) || echo ">>> DRY RUN — re-run with --apply to make changes"

run() { echo "  $*"; (( APPLY )) || return 0; "$@"; }

echo "== monitoring network"
if docker network inspect monitoring >/dev/null 2>&1; then
  echo "  exists"
else
  run docker network create monitoring
fi

echo "== directories"
# Owner is left to the image on both: immich-server and postgres each create
# their tree on first start under whatever uid they run as. Creating these
# empty and letting the containers populate them is the supported path.
run mkdir -p "$UPLOAD_LOCATION" "$DB_DATA_LOCATION"

echo "== backup read access (originals only)"
# DB_DATA_LOCATION is deliberately excluded: it is never a backup source (the
# dump hook handles the database), and Postgres refuses to start on a
# group-readable pgdata without --allow-group-access.
if getent group storage >/dev/null; then
  run chgrp -R storage "$UPLOAD_LOCATION"
  run chmod -R g+rX "$UPLOAD_LOCATION"
  run chmod g+s "$UPLOAD_LOCATION"
else
  echo "  no 'storage' group — run apps/borgui/setup-permissions.sh --apply first"
fi
echo "  untouched: $DB_DATA_LOCATION"

(( APPLY )) && echo "done — now: docker compose up -d" || echo ">>> DRY RUN — nothing changed"
