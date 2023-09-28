#!/usr/bin/env bash

set -e

semaphore_file="/Users/cltbld/Library/Preferences/semaphore/safari-update-has-run"
semaphore_version="2"
mkdir -p "$(dirname "$semaphore_file")"
# this script runs as root, but other scripts write files to this dir
#   and run as cltbld, so fix ownership
chown cltbld "$(dirname "$semaphore_file")"
touch "$semaphore_file"
if [[ "$(cat "$semaphore_file")" == "$semaphore_version" ]]; then
  echo "$0: file indicates this version of the script has already run. exiting..."
  exit 0
else
  echo "$0: running..."
fi

# -i to install.
softwareupdate -l; softwareupdate -i "Safari15.6.1CatalinaAuto-15.6.1"

echo "$semaphore_version" > "$semaphore_file"
