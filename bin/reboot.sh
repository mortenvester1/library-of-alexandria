#!/bin/bash

# A script to perform incremental backups using rsync
set -o errexit
set -o nounset
set -o pipefail

touch /home/pi/rebooting
sudo /sbin/reboot

# crontab -e
# 45 2 * * * /path/to/script for every day 2:45am
