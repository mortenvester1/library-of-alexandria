#!/usr/bin/env bash
# Reports whether Borg UI can actually read every backup source. Read-only:
# changes nothing. Run it after setup-permissions.sh, and again after any app
# upgrade that might have recreated files under a different UID.
#
#   ./check-permissions.sh
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a

: "${PUID:?set PUID in .env}"
: "${PGID:?set PGID in .env}"
: "${STORAGE_PATH:=/mnt/storage}"
: "${DUMPS_PATH:=/mnt/storage/dumps}"
: "${BORG_REPO_PATH:=/mnt/backup/@borg}"
: "${BORGUI_DATA_PATH:=/mnt/storage/borgui-data}"

# Container-side paths, because that is where Borg actually reads from. Kept in
# step with the plan sources in hooks/README.md.
SOURCES=(
  /local/storage/couchdb/data
  /local/storage/immich/data
  /local/storage/seafile/data
  /local/storage/movies
  /local/storage/music
  /local/storage/shows
)
WRITABLE=(/local/dumps /local/backup)

echo "== ownership on disk"
# Trailing / on the globs keeps this to directories.
stat -c '%U:%G %a %n' \
  "$STORAGE_PATH"/*/ "$STORAGE_PATH"/*/*/ \
  "$DUMPS_PATH" "$BORGUI_DATA_PATH" "$BORG_REPO_PATH" 2>/dev/null || true

echo
echo "== group membership"
getent group storage || echo "no 'storage' group — run setup-permissions.sh"
# Membership added by usermod does not reach an already-open shell. `id` reads
# the current session's credentials; getent reads the group file. If the two
# disagree, log out and back in.
echo "current shell: $(id -nG)"

echo
echo "== PGID sanity"
storage_gid="$(getent group storage | cut -d: -f3 || true)"
if [[ -n "$storage_gid" && "$PGID" != "$storage_gid" ]]; then
  echo "WARNING: PGID=$PGID but storage gid=$storage_gid — Borg is not in the read channel"
else
  echo "PGID=$PGID matches the storage group"
fi

echo
echo "== readability as $PUID:$PGID inside the container"
if ! docker ps --format '{{.Names}}' | grep -qx borg-web-ui; then
  echo "borg-web-ui not running — start the stack to run this check"
  exit 1
fi

fail=0
for path in "${SOURCES[@]}"; do
  # -print with ! -readable lists exactly what Borg would skip or error on.
  out="$(docker exec -u "$PUID:$PGID" borg-web-ui \
          find "$path" ! -readable -print 2>&1 || true)"
  if [[ -n "$out" ]]; then
    echo "UNREADABLE under $path:"
    echo "$out" | head -20
    fail=1
  else
    echo "ok  $path"
  fi
done

for path in "${WRITABLE[@]}"; do
  if docker exec -u "$PUID:$PGID" borg-web-ui test -w "$path"; then
    echo "ok  $path (writable)"
  else
    echo "NOT WRITABLE: $path"
    fail=1
  fi
done

echo
if (( fail )); then
  echo "FAIL — fix with setup-permissions.sh --apply, then re-run this"
  exit 1
fi
echo "PASS — every source readable, every target writable"
