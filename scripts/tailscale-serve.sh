#!/usr/bin/env bash
# Declare the full `tailscale serve` mapping for this machine's apps, so every
# service has one HTTPS URL on the tailnet instead of a plain-HTTP host port.
#
# The certificate covers the hostname, not the port, so each app needs its own
# --https port. The mapping itself lives in the gitignored
# `tailscale-serve-port-map` next to this script — see the .example for its
# format, and override the path with PORT_MAP_FILE.
#
# Writing the serve config needs root, unless `sudo tailscale set
# --operator=$USER` has been run once on this machine.
#
# Dry run by default:
#   ./tailscale-serve.sh
#   sudo ./tailscale-serve.sh --apply
#   sudo ./tailscale-serve.sh --apply --reset   # drop the existing mapping first
set -euo pipefail

APPLY=0
RESET=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --reset) RESET=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
(( APPLY )) || echo ">>> DRY RUN — re-run with --apply to make changes"

for bin in tailscale jq; do
  command -v "$bin" >/dev/null || { echo "$bin not on PATH" >&2; exit 1; }
done

run() { echo "  $*"; (( APPLY )) || return 0; "$@"; }

cd "$(dirname "$0")"
PORT_MAP_FILE="${PORT_MAP_FILE:-tailscale-serve-port-map}"

echo "== prerequisites"
if [[ ! -f "$PORT_MAP_FILE" ]]; then
  echo "  no $PORT_MAP_FILE — cp tailscale-serve-port-map.example $PORT_MAP_FILE first" >&2
  exit 1
fi

MAPPING=()
declare -A SEEN=()
while read -r https_port local_port name; do
  [[ -z "$https_port" || "$https_port" == \#* ]] && continue
  # A bad port silently becomes a mapping nobody can reach, so reject it here
  # rather than letting `serve` take it.
  [[ "$https_port" =~ ^[0-9]+$ && "$local_port" =~ ^[0-9]+$ ]] || {
    echo "  bad line in $PORT_MAP_FILE: $https_port $local_port $name" >&2; exit 1; }
  # A reused https port would silently drop whichever app lost the race.
  [[ -n "${SEEN[$https_port]:-}" ]] && {
    echo "  $https_port is mapped twice in $PORT_MAP_FILE" >&2; exit 1; }
  SEEN[$https_port]=1
  MAPPING+=("$https_port $local_port ${name:-$local_port}")
done <"$PORT_MAP_FILE"
(( ${#MAPPING[@]} )) || { echo "  $PORT_MAP_FILE declares no apps" >&2; exit 1; }
echo "  port map: $PORT_MAP_FILE (${#MAPPING[@]} apps)"
HOSTNAME_TS="$(tailscale status --json | jq -r '.CertDomains[0] // empty')"
if [[ -z "$HOSTNAME_TS" ]]; then
  # Without HTTPS enabled tailnet-wide (admin console -> DNS -> HTTPS
  # Certificates) serve cannot get a certificate and every mapping below fails.
  echo "  no cert domain — enable HTTPS for the tailnet in the admin console" >&2
  exit 1
fi
echo "  cert domain: $HOSTNAME_TS"

if (( RESET )); then
  echo "== reset"
  run tailscale serve reset
fi

echo "== mapping"
for entry in "${MAPPING[@]}"; do
  read -r https_port local_port name <<<"$entry"
  printf '  %-13s https://%s:%s -> http://127.0.0.1:%s\n' "$name" "$HOSTNAME_TS" "$https_port" "$local_port"
  run tailscale serve --bg --https="$https_port" "http://127.0.0.1:$local_port"
done

echo "== result"
(( APPLY )) && tailscale serve status || echo ">>> DRY RUN — nothing changed"
