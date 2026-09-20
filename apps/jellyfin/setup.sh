#!/usr/bin/env bash
# Prerequisites for apps/jellyfin: the three state directories, and a check that
# the media library is actually there and readable.
#
# Unlike the other stacks this one needs no `sudo` — everything it creates lives
# in your home directory and is owned by you.
#
# Dry run by default:
#   ./setup.sh
#   ./setup.sh --apply
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a
: "${JELLYFIN_DATA_PATH:?set JELLYFIN_DATA_PATH in .env}"
: "${JELLYFIN_CONFIG_PATH:?set JELLYFIN_CONFIG_PATH in .env}"
: "${JELLYFIN_CACHE_PATH:?set JELLYFIN_CACHE_PATH in .env}"
: "${MEDIA_PATH:?set MEDIA_PATH in .env}"

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
(( APPLY )) || echo ">>> DRY RUN — re-run with --apply to make changes"

run() { echo "  $*"; (( APPLY )) || return 0; "$@"; }

echo "== state directories"
# No chown: the container runs as root and writes as root, and these live under
# your home directory. Whatever is already there keeps its ownership.
for d in "$JELLYFIN_DATA_PATH" "$JELLYFIN_CONFIG_PATH" "$JELLYFIN_CACHE_PATH"; do
  if [[ -d "$d" ]]; then
    echo "  exists: $d"
  else
    run mkdir -p "$d"
  fi
done

echo "== media library (read-only, never created here)"
# Creating a missing media dir would give Jellyfin an empty library and a
# successful start, which is worse than failing.
missing=0
for sub in shows movies music; do
  if [[ -d "$MEDIA_PATH/$sub" ]]; then
    echo "  ok: $MEDIA_PATH/$sub"
  else
    echo "  MISSING: $MEDIA_PATH/$sub"
    missing=1
  fi
done
(( missing )) && { echo "fix the media paths before starting" >&2; exit 1; }

echo "== sudo check"
# The compose file no longer reads ${HOME}, but running compose as root still
# means the container writes root-owned files into your home directory.
if [[ -n "${SUDO_USER:-}" ]]; then
  echo "  WARNING: running under sudo. Do not 'sudo docker compose up' here."
else
  echo "  ok: not under sudo"
fi

(( APPLY )) && echo "done — now: docker compose up -d" || echo ">>> DRY RUN — nothing changed"
