#!/usr/bin/env bash
# Prerequisites for apps/seafile: the two host directories and the shared
# monitoring network. Two more steps are only possible AFTER the first start —
# see README.md.
#
# Dry run by default:
#   sudo ./setup.sh
#   sudo ./setup.sh --apply
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a
: "${SEAFILE_VOLUME:?set SEAFILE_VOLUME in .env}"
: "${SEAFILE_MYSQL_VOLUME:?set SEAFILE_MYSQL_VOLUME in .env}"

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
# seafile-mc runs as root and populates /shared itself; MariaDB does the same
# with its own uid. Both just need the directory to exist.
run mkdir -p "$SEAFILE_VOLUME" "$SEAFILE_MYSQL_VOLUME"

echo "== backup read access (library blobs only)"
# SEAFILE_MYSQL_VOLUME is deliberately excluded: never a backup source, since
# the dump hook handles the three databases.
if getent group storage >/dev/null; then
  run chgrp -R storage "$SEAFILE_VOLUME"
  run chmod -R g+rX "$SEAFILE_VOLUME"
  run chmod g+s "$SEAFILE_VOLUME"
else
  echo "  no 'storage' group — run apps/borgui/setup-permissions.sh --apply first"
fi
echo "  untouched: $SEAFILE_MYSQL_VOLUME"

(( APPLY )) && echo "done — now: docker compose up -d" || echo ">>> DRY RUN — nothing changed"
