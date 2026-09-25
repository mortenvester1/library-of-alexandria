#!/usr/bin/env bash
# Two workarounds for bugs in the published TimeNest samba image, applied before
# handing control to upstream's own entrypoint. Both no-op once upstream fixes
# them, so this stays a thin shim rather than a fork.
#
# 1. `--log-stdout`
#    entrypoint-samba.sh starts smbd with --log-stdout, renamed --debug-stdout
#    in Samba 4.15. The image is debian:bookworm-slim with 4.17.12, so smbd
#    exits on the unknown option and the container crash-loops.
#
# 2. `include = /etc/timenest/shares.d/*.conf`
#    Samba's `include` takes ONE file and does not glob — a wildcard matches
#    nothing and is ignored silently, with no testparm warning. Every per-user
#    share the web UI writes is therefore invisible to smbd: the Mac sees the
#    server over Bonjour, authenticates, and finds no share to back up to.
#    We point the include at a single aggregate file and keep it in sync.
#
# 3. POSIX accounts live only in the container's writable layer
#    create-user.sh runs `useradd` inside the container, but only
#    /var/lib/samba (passdb.tdb) is persisted. Any recreate — an image bump, a
#    compose edit — drops /etc/passwd back to the image's copy while passdb
#    keeps the Samba accounts, and smbd then refuses every login with "Failed
#    to find a Unix account for <user>". We rebuild the missing accounts from
#    the share fragments, reusing the uid/gid that already own each backup
#    directory so existing data stays reachable.
set -euo pipefail

SHARES_DIR=/etc/timenest/shares.d
AGGREGATE=/etc/samba/shares.conf
TEMPLATE=/etc/timenest/smb.conf.template

log() { printf '[compat] %s\n' "$*"; }

# (1) — the sed matches nothing if upstream has fixed the flag.
patched=/tmp/entrypoint-samba.sh
sed 's/--log-stdout/--debug-stdout/' /usr/local/bin/entrypoint-samba.sh > "$patched"

# (2) — rewrite the include in the template the entrypoint renders from.
if grep -q '^\s*include = .*shares\.d/\*\.conf' "$TEMPLATE"; then
    sed -i "s#^\( *include = \).*shares\.d/\*\.conf#\1${AGGREGATE}#" "$TEMPLATE"
    log "include rewritten to ${AGGREGATE}"
fi

# Build it once before smbd starts so existing users work immediately.
mkdir -p "$SHARES_DIR"
cat "$SHARES_DIR"/*.conf > "$AGGREGATE" 2>/dev/null || : > "$AGGREGATE"

# (3) — one POSIX account per share fragment, at the uid/gid that already owns
# the backup directory. Nothing to do on a container that create-user.sh has
# already run in; this only fires after a recreate.
for conf in "$SHARES_DIR"/*.conf; do
    [[ -e "$conf" ]] || break
    user=$(basename "$conf" .conf)
    id "$user" &>/dev/null && continue
    dir="/backup/$user"
    uid=$(stat -c %u "$dir" 2>/dev/null || true)
    gid=$(stat -c %g "$dir" 2>/dev/null || true)
    if [[ -n "$gid" ]] && ! getent group "$gid" >/dev/null; then
        groupadd --system --gid "$gid" "$user"
    fi
    useradd --system --no-create-home --shell /usr/sbin/nologin \
        ${uid:+--uid "$uid"} ${gid:+--gid "$gid"} "$user"
    log "restored POSIX account $user (uid=${uid:-auto} gid=${gid:-auto})"
done

# create-user.sh writes a fragment and SIGHUPs smbd, which re-reads smb.conf and
# therefore the aggregate — but only if the aggregate already reflects the new
# fragment. Poll instead of racing that SIGHUP; 5s is well inside the time it
# takes someone to click through the UI and open Time Machine.
(
    while :; do
        new=$(cat "$SHARES_DIR"/*.conf 2>/dev/null || true)
        if [[ "$new" != "$(cat "$AGGREGATE" 2>/dev/null || true)" ]]; then
            printf '%s\n' "$new" > "$AGGREGATE"
            log "shares changed; reloading smbd"
            smbcontrol smbd reload-config >/dev/null 2>&1 || true
        fi
        sleep 5
    done
) &

exec bash "$patched"
