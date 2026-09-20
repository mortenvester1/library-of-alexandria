#!/usr/bin/env bash
# CouchDB: stop before backup. The .couch files are append-only, but a live copy
# can still catch a partial header rewrite, and this database is small enough
# (Obsidian LiveSync) that a minute of downtime costs nothing.
# Paired with post-couchdb.sh, which MUST be set to run on failure too.
set -euo pipefail

container="${COUCHDB_CONTAINER:-couchdb}"

if docker ps --format '{{.Names}}' | grep -qx "$container"; then
  docker stop "$container"
fi
