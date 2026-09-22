#!/usr/bin/env bash

set -e

# The semaphore lives in a root-owned tree. It used to live under
# /Users/cltbld/Library/Preferences/semaphore, which this script (running as
# root on every converge) created and then chown'd to cltbld. Because chown
# follows symlinks, the untrusted task user could replace that directory with a
# symlink and have root hand it ownership of any directory on the system
# (e.g. /usr/local/bin, which holds root-executed scripts) -- a deterministic
# local escalation to root. Nothing but this script needs the semaphore, so
# keep it somewhere cltbld cannot influence and drop the chown entirely.
semaphore_dir="/var/db/ronin-semaphores"
semaphore_file="${semaphore_dir}/safari-update-has-run"
legacy_semaphore_file="/Users/cltbld/Library/Preferences/semaphore/safari-update-has-run"
semaphore_version="2"

install -d -o root -g wheel -m 0755 "$semaphore_dir"

# One-time migration for hosts that converged before the semaphore moved: they
# already applied the update, so seed the root-owned semaphore instead of
# re-running softwareupdate across the fleet. Read the legacy path as cltbld so
# root never follows a cltbld-controlled symlink, not even for a read.
if [[ ! -f "$semaphore_file" ]]; then
  legacy_contents="$(sudo -u cltbld /bin/cat "$legacy_semaphore_file" 2>/dev/null || true)"
  if [[ "$legacy_contents" == "$semaphore_version" ]]; then
    echo "$semaphore_version" > "$semaphore_file"
  fi
fi

if [[ -f "$semaphore_file" && "$(cat "$semaphore_file")" == "$semaphore_version" ]]; then
  echo "$0: file indicates this version of the script has already run. exiting..."
  exit 0
else
  echo "$0: running..."
fi

# -i to install.
softwareupdate -l; softwareupdate -i "Safari15.6.1CatalinaAuto-15.6.1"

echo "$semaphore_version" > "$semaphore_file"
