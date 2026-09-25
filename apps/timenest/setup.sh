#!/usr/bin/env bash
# Prerequisites for apps/timenest: state directories, the backup subvolume, the
# two host-level port conflicts (smbd on 445, avahi on 5353), and the Bonjour
# service file that replaces upstream's avahi container.
#
# Dry run by default:
#   ./setup.sh
#   ./setup.sh --apply
set -euo pipefail

cd "$(dirname "$0")"
[[ -f .env ]] || { echo "no .env here — cp .env.example .env first" >&2; exit 1; }
set -a; . ./.env; set +a
: "${BACKUP_PATH:?set BACKUP_PATH in .env}"
: "${TIMENEST_SAMBA_STATE:?set TIMENEST_SAMBA_STATE in .env}"
: "${TIMENEST_CONFIG_PATH:?set TIMENEST_CONFIG_PATH in .env}"
: "${TIMENEST_WEB_DATA:?set TIMENEST_WEB_DATA in .env}"
: "${ADMIN_PASSWORD:?set ADMIN_PASSWORD in .env}"
export SERVER_NAME="${SERVER_NAME:-TimeNest}"
export DEVICE_MODEL="${DEVICE_MODEL:-TimeCapsule8,119}"

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
(( APPLY )) || echo ">>> DRY RUN — re-run with --apply to make changes"

run() { echo "  $*"; (( APPLY )) || return 0; "$@"; }

echo "== backup target (never created here)"
# Creating it would give Samba an empty directory on the root filesystem and a
# successful start — the drive silently not mounted. Failing is better.
# It is a btrfs subvolume with chattr +C; see apps/borgui/README.md.
[[ -d "$BACKUP_PATH" ]] || { echo "  MISSING: $BACKUP_PATH — create the subvolume first (apps/borgui/README.md)" >&2; exit 1; }
echo "  ok: $BACKUP_PATH"

echo "== state directories"
# Both containers run as root (verified: `id` in timenest-web is uid=0), so
# ownership is not about them being able to write. It is about Borg UI, which
# mounts /mnt/storage read-only as PUID:PGID and would otherwise skip these.
# setgid so anything created underneath keeps the storage group.
owner="${TIMENEST_STATE_OWNER:-$(id -un):storage}"
# shares.d is the actual bind target for samba; see docker-compose.yaml.
for d in "$TIMENEST_SAMBA_STATE" "$TIMENEST_CONFIG_PATH" "$TIMENEST_CONFIG_PATH/shares.d" "$TIMENEST_WEB_DATA"; do
  if [[ -d "$d" ]]; then echo "  exists: $d"; else run sudo mkdir -p "$d"; fi
  run sudo chown "$owner" "$d"
  # Samba checks its state directory and warns "should have permissions 0755
  # for browsing to work" on anything else — the setgid bit included. The owner
  # is already Borg UI's PUID, so 0755 costs it nothing there.
  if [[ "$d" == "$TIMENEST_SAMBA_STATE" ]]; then
    run sudo chmod 0755 "$d"
  else
    run sudo chmod 2775 "$d"
  fi
done

echo "== port 445 (host smbd)"
# A host smbd holding 445 makes the container exit; worse, if it starts first
# after a reboot the Macs back up to the wrong share.
if systemctl is-active --quiet smbd 2>/dev/null; then
  echo "  CONFLICT: host smbd is running. Stop and mask it:"
  echo "    sudo systemctl disable --now smbd nmbd && sudo systemctl mask smbd"
  exit 1
fi
echo "  ok: host smbd not running"

echo "== port 5353 (host avahi-daemon)"
# The opposite check: this stack has no avahi container precisely because the
# host daemon owns 5353 and apps/entrance depends on it.
if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
  echo "  ok: host avahi-daemon running — it will carry the advertisement"
else
  echo "  WARNING: host avahi-daemon is not running. The share will work over"
  echo "  SMB but will not appear in Finder or Time Machine on its own."
fi

echo "== Bonjour service file"
# Replaces upstream's timenest-avahi container. avahi re-reads
# /etc/avahi/services/ on change; no restart needed.
command -v envsubst >/dev/null || { echo "  envsubst missing (install gettext)" >&2; exit 1; }

# One dkN record per share. adVN must be the SHARE name — macOS mounts
# smb://<host>/<adVN>. Upstream advertises the server name there, so the Mac
# lists the server in Time Machine and then fails to connect to a share that
# does not exist. Shares are created by the web UI, so re-run this after adding
# or removing a user.
ADISK_VOLUMES=""
i=0
for conf in "$TIMENEST_CONFIG_PATH"/shares.d/*.conf; do
  [[ -e "$conf" ]] || break
  share="$(basename "$conf" .conf)"
  ADISK_VOLUMES+="    <txt-record>dk${i}=adVN=${share},adVF=0x82</txt-record>"$'\n'
  echo "  volume dk${i}: ${share}"
  i=$((i + 1))
done
ADISK_VOLUMES="${ADISK_VOLUMES%$'\n'}"
export ADISK_VOLUMES
if (( i == 0 )); then
  echo "  no shares yet — add a user in the web UI, then re-run this script"
fi

tmp="$(mktemp)"
envsubst '${SERVER_NAME} ${DEVICE_MODEL} ${ADISK_VOLUMES}' < ./timenest.service > "$tmp"
if [[ -f /etc/avahi/services/timenest.service ]] && cmp -s "$tmp" /etc/avahi/services/timenest.service; then
  echo "  up to date: /etc/avahi/services/timenest.service"
  rm -f "$tmp"
else
  echo "  install /etc/avahi/services/timenest.service (SERVER_NAME=$SERVER_NAME)"
  if (( APPLY )); then
    sudo install -m 0644 "$tmp" /etc/avahi/services/timenest.service
  fi
  rm -f "$tmp"
fi

echo "== firewall"
# smbd binds fine and logs nothing while a host firewall drops the SYN, which
# looks exactly like a Samba problem from the Mac: the server appears in Time
# Machine (mDNS is allowed) and then will not connect.
if command -v ufw >/dev/null && systemctl is-active --quiet ufw 2>/dev/null; then
  v4=$(sudo -n ufw status 2>/dev/null | grep -c "^445.*ALLOW" || true)
  v6=$(sudo -n ufw status 2>/dev/null | grep -c "^445.*(v6).*ALLOW" || true)
  if (( v4 > 0 && v6 > 0 )); then
    echo "  ok: ufw has rules for 445 on both address families"
  elif (( v4 > 0 )); then
    echo "  ufw allows 445 over IPv4 only. The host also has a AAAA record, and"
    echo "  macOS will try it: mDNS answers over v6 while SMB is dropped, which"
    echo "  looks like a Time Machine failure. Add the v6 rule too:"
    echo "    sudo ufw allow from <lan-v6-prefix>::/64 to any port 445 proto tcp"
  else
    echo "  ufw is active with no visible rule for 445/tcp. Allow it from the LAN:"
    echo "    sudo ufw allow from <lan>/24 to any port 445 proto tcp comment 'timenest smb'"
  fi
else
  echo "  ok: ufw not active"
fi

echo "== monitoring network"
if docker network inspect monitoring >/dev/null 2>&1; then
  echo "  ok: monitoring network exists"
else
  run docker network create monitoring
fi

echo "== admin password"
[[ "$ADMIN_PASSWORD" == "changeme-please" ]] && { echo "  ADMIN_PASSWORD is still upstream's default" >&2; exit 1; }
echo "  ok: set"

(( APPLY )) && echo "done — now: docker compose up -d" || echo ">>> DRY RUN — nothing changed"
