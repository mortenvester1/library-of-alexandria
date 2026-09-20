#!/usr/bin/env bash
# CouchDB: restart after backup. Attach with the run condition set to "always",
# not "on success" — otherwise a failed backup leaves CouchDB down until someone
# notices. BORG_UI_BACKUP_STATUS is deliberately not checked here.
set -euo pipefail

container="${COUCHDB_CONTAINER:-couchdb}"

if docker ps -a --format '{{.Names}}' | grep -qx "$container"; then
  docker start "$container"
fi
