#!/usr/bin/env bash

# place at /usr/sbin/cltbld-and-apt-cleaner.sh
# chmod 700 /usr/sbin/cltbld-and-apt-cleaner.sh

set -e
# set -x

# check that the user is root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

SECONDS=0
root_usage=$(df --output=pcent / | tail -1 | tr -dc "0-9")
boot_usage=$(df --output=pcent /boot | tail -1 | tr -dc "0-9")

echo "Root disk usage is ${root_usage}%"
echo "Boot disk usage is ${boot_usage}%"

if [ "$root_usage" -le 70 ] && [ "$boot_usage" -le 70 ]; then
  echo "Disk usage below thresholds, skipping cleanup. Elapsed: ${SECONDS}s"
  exit 0
fi

echo "Disk usage above threshold, performing cleanup..."

if [ "$root_usage" -gt 70 ]; then
  echo "Cleaning up build caches..."
  for target in /home/cltbld/.mozbuild \
                /home/cltbld/caches \
                /home/cltbld/file-caches.json \
                /home/cltbld/directory-caches.json; do
      if [ -e "$target" ]; then
          size=$(du -sh "$target" 2>/dev/null | cut -f1)
          echo "  removing $target ($size)"
          rm -rf "$target"
      else
          echo "  skipping $target (not present)"
      fi
  done
else
  echo "Root disk usage below threshold; skipping build cache cleanup"
fi

echo "Cleaning up apt/deb..."
apt-get autoremove -y
apt-get clean
echo "Cleanup complete. Elapsed: ${SECONDS}s"
exit 0
