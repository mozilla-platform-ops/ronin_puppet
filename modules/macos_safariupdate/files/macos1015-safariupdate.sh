#!/usr/bin/env bash

set -e

current_user=$(id -u -n)
semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-update-has-run"
semaphore_version="1"
mkdir -p "$(dirname "$semaphore_file")"
touch "$semaphore_file"
if [[ "$(cat "$semaphore_file")" == "$semaphore_version" ]]; then
  echo "$0: file indicates this version of the script has already run. exiting..."
  exit 0
else
  echo "$0: running..."
fi

# Fetch latest updates
softwareupdate -l
# Hardcoded to sarafi 15.6.1
# TODO: Improve this to be able to get a version number from puppet
softwareupdate -i "Safari15.6.1CatalinaAuto-15.6.1"

echo "$semaphore_version" > "$semaphore_file"