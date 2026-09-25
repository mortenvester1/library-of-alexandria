#!/usr/bin/env bash
# Upstream's entrypoint-samba.sh ends with:
#
#   smbd --foreground --log-stdout --no-process-group --configfile=...
#
# `--log-stdout` was renamed `--debug-stdout` in Samba 4.15. The image is built
# on debian:bookworm-slim, which ships 4.17.12, so smbd exits with "Invalid
# option --log-stdout: unknown option" and the container crash-loops. Upstream's
# own README claims Samba 4.18+; the published image does not have it.
#
# Patching the one flag is cheaper than vendoring the whole entrypoint, and this
# no-ops the day upstream fixes it — the sed simply matches nothing.
set -euo pipefail

src=/usr/local/bin/entrypoint-samba.sh
patched=/tmp/entrypoint-samba.sh

sed 's/--log-stdout/--debug-stdout/' "$src" > "$patched"
exec bash "$patched"
