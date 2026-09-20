#!/usr/bin/env bash
# Prerequisites for apps/couchdb: the data directory, its ownership, and the
# shared monitoring network. Everything here must be true BEFORE the first
# `docker compose up` — the container exits immediately on a data dir it does
# not own.
#
# Dry run by default:
#   sudo ./setup.sh
#   sudo ./setup.sh --apply
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a
: "${COUCHDB_DATA:?set COUCHDB_DATA in .env}"

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

echo "== data directory"
# 5984 is fixed by the image; the entrypoint checks ownership and nothing else
# will satisfy it.
run mkdir -p "$COUCHDB_DATA"
run chown -R 5984:5984 "$COUCHDB_DATA"

echo "== backup read access"
# Group-read so apps/borgui can archive this without running as root. Harmless
# if the storage group does not exist yet.
if getent group storage >/dev/null; then
  run chgrp -R storage "$COUCHDB_DATA"
  run chmod -R g+rX "$COUCHDB_DATA"
  run chmod g+s "$COUCHDB_DATA"
else
  echo "  no 'storage' group — run apps/borgui/setup-permissions.sh --apply first"
fi

(( APPLY )) && echo "done — now: docker compose up -d" || echo ">>> DRY RUN — nothing changed"
