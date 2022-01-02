#!/bin/bash

# A script to perform incremental backups using rsync
set -o errexit
set -o nounset
set -o pipefail


# Back up media
readonly SOURCE_DIR="/mnt/storage/media"
readonly BACKUP_DIR="/mnt/backup/media"

mkdir -p "${BACKUP_DIR}"
rsync -av --delete \
  "${SOURCE_DIR}/" \
  --exclude=".cache" \
  "${BACKUP_DIR}"

# crontab -e
# 0 3 * * 0 /path/to/script for every sunday 3am backup
