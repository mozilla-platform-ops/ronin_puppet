#!/bin/bash
#
# Apple's CoreSimulator framework reads its SDK->runtime override map
# strictly from ~/Library/Developer/CoreSimulator/RuntimeMap.plist; the
# system path /Library/Developer/CoreSimulator/RuntimeMap.plist is not
# honored. generic-worker-multiuser spawns a fresh task_<id> user per
# task whose home has no RuntimeMap.plist, so the override does not
# apply and ibtool fails with "iOS 26.2 Platform Not Installed".
#
# This script copies the canonical RuntimeMap.plist from /Library/...
# into each existing task_* user's home. The copy is performed as that
# task user, never as root -- see the comment above the loop. It is
# invoked by a LaunchDaemon whose WatchPaths is /Users, so it runs
# within ~1s of generic-worker creating a new task user.
#
# Removable once Apple ships an Xcode/runtime pair without the
# 23C57 (unavailable) <-> 23D8133 (available) mismatch.

set -eu

SRC="/Library/Developer/CoreSimulator/RuntimeMap.plist"

if [ ! -f "$SRC" ]; then
  exit 0
fi

# Everything below /Users/task_* is owned and writable by the untrusted task
# user. This script runs as root, and BSD install(1) chowns/chmods the final
# path even when it already exists, following symlinks as it goes -- so doing
# the copy as root let a task plant
#
#   /Users/task_abc/Library/Developer/CoreSimulator -> /usr/local/bin
#
# and have root hand /usr/local/bin to task_abc, which is a root escalation via
# the scripts puppet and the LaunchDaemons execute from there. The daemon's
# WatchPaths is /Users, so the task user can retrigger it at will.
#
# The copy does not need root: the file only ever lands in the task user's own
# home, owned by that user. Drop privileges and let the kernel enforce what the
# path checks cannot. The source is root-owned 0644 and world-readable, so the
# task user can read it.
for home in /Users/task_*; do
  [ -d "$home" ] || continue
  user="$(basename "$home")"

  if ! dscl . -read "/Users/${user}" >/dev/null 2>&1; then
    continue
  fi

  dst="${home}/Library/Developer/CoreSimulator/RuntimeMap.plist"

  # Compare as the task user too: as root, cmp would read through an
  # attacker-planted symlink to a file root can see and the user cannot.
  if sudo -u "$user" /usr/bin/cmp -s "$SRC" "$dst" 2>/dev/null; then
    continue
  fi

  if ! sudo -u "$user" /usr/bin/install -d -m 0755 \
      "${home}/Library/Developer/CoreSimulator"; then
    echo "coresim-runtimemap-sync: could not create CoreSimulator dir for ${user}" >&2
    continue
  fi

  if ! sudo -u "$user" /usr/bin/install -m 0644 "$SRC" "$dst"; then
    echo "coresim-runtimemap-sync: could not install RuntimeMap.plist for ${user}" >&2
    continue
  fi
done
