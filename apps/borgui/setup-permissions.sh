#!/usr/bin/env bash
# Puts Borg UI in the read channel for every backup source, and creates the
# directories the stack needs.
#
# Dry run by default — prints what it would do and touches nothing:
#   sudo ./setup-permissions.sh
#   sudo ./setup-permissions.sh --apply
#
# It never changes a directory's OWNER. Each app's uid is dictated by its image
# (couchdb refuses anything but 5984, postgres likewise), so this only sets the
# GROUP to `storage` and adds group-read. Borg UI then runs with PGID=<storage>
# and can read everything without anything running as root.
#
# Deliberately skipped: the live database directories. They are excluded from
# every backup plan, so Borg never reads them, and postgres refuses to start on
# a group-readable pgdata without --allow-group-access.
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a

: "${PUID:?set PUID in .env}"
: "${STORAGE_PATH:=/mnt/storage}"
: "${DUMPS_PATH:=/mnt/storage/dumps}"
: "${BORG_REPO_PATH:=/mnt/backup/@borg}"
: "${BORGUI_DATA_PATH:=/mnt/storage/borgui-data}"

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
(( APPLY )) || echo ">>> DRY RUN — re-run with --apply to make changes"

run() {
  echo "  $*"
  (( APPLY )) || return 0
  "$@"
}

# App data: group + read only, owner untouched.
SHARED=(
  "$STORAGE_PATH/couchdb/data"
  "$STORAGE_PATH/immich/data"
  "$STORAGE_PATH/seafile/data"
  "$STORAGE_PATH/movies"
  "$STORAGE_PATH/music"
  "$STORAGE_PATH/shows"
)
# Borg UI's own directories: it owns these outright.
OWNED=("$DUMPS_PATH" "$BORGUI_DATA_PATH" "$BORG_REPO_PATH")
# Never touched. Excluded from every plan; see hooks/README.md.
SKIP=("$STORAGE_PATH/immich/db" "$STORAGE_PATH/seafile/mysql")

echo "== storage group"
if getent group storage >/dev/null; then
  echo "  exists: $(getent group storage)"
else
  run groupadd storage
fi
storage_gid="$(getent group storage | cut -d: -f3)"
storage_gid="${storage_gid:-<new>}"

target_user="${SUDO_USER:-$USER}"
if id -nG "$target_user" | tr ' ' '\n' | grep -qx storage; then
  echo "  $target_user already in storage"
else
  run usermod -aG storage "$target_user"
  echo "  NOTE: log out and back in before your shell sees this"
fi

echo
echo "== Borg UI's own directories -> $PUID:storage, 2750"
for d in "${OWNED[@]}"; do
  [[ -d "$d" ]] || run mkdir -p "$d"
  run chown -R "$PUID:storage" "$d"
  # setgid so files created later inherit the group instead of the creator's.
  run chmod 2750 "$d"
done

echo
echo "== app data -> group storage, group-read, owner left alone"
for d in "${SHARED[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "  skip (missing): $d"
    continue
  fi
  # -prune keeps the recursion out of the live database dirs even if one ever
  # ends up nested under a source.
  prune=()
  for s in "${SKIP[@]}"; do prune+=(-path "$s" -prune -o); done

  echo "  $d"
  if (( APPLY )); then
    find "$d" "${prune[@]}" -print0 | xargs -0 -r chgrp storage
    # g+rX: read on files, traverse on directories. Never g+w — Borg only reads.
    find "$d" "${prune[@]}" -print0 | xargs -0 -r chmod g+rX
    find "$d" "${prune[@]}" -type d -print0 | xargs -0 -r chmod g+s
  else
    echo "    chgrp storage -R (excluding: ${SKIP[*]})"
    echo "    chmod g+rX -R, g+s on directories"
  fi
done

echo
echo "== left untouched (excluded from every backup plan)"
for s in "${SKIP[@]}"; do echo "  $s"; done

echo
echo "storage gid = $storage_gid — set PGID to this in .env"
(( APPLY )) && echo "now run ./check-permissions.sh" || echo ">>> DRY RUN — nothing changed"
