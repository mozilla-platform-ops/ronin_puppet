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
usage=$(df --output=pcent / | tail -1 | tr -dc "0-9")
echo "Disk usage is ${usage}%"
if [ "$usage" -le 70 ]; then
  echo "Disk usage below threshold, skipping cleanup. Elapsed: ${SECONDS}s"
  exit 0
fi

echo "Disk usage above 70%, performing cleanup..."

echo "Cleaning up build caches..."
rm -rf /home/cltbld/.mozbuild \
       /home/cltbld/caches \
       /home/cltbld/file-caches.json \
       /home/cltbld/directory-caches.json

echo "Cleaning up apt/deb..."
apt-get autoremove -y
apt-get clean
echo "Cleanup complete. Elapsed: ${SECONDS}s"
echo "Rebooting in 5 minutes..."
shutdown -r +5 "System will reboot in 5 minutes due to high disk usage cleanup."
exit 0
