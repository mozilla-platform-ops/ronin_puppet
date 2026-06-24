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
# into each existing task_* user's home, fixing ownership/mode. It is
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

for home in /Users/task_*; do
  [ -d "$home" ] || continue
  user="$(basename "$home")"

  if ! dscl . -read "/Users/${user}" >/dev/null 2>&1; then
    continue
  fi

  dst="${home}/Library/Developer/CoreSimulator/RuntimeMap.plist"
  if [ -f "$dst" ] && cmp -s "$SRC" "$dst"; then
    continue
  fi

  install -d -o "$user" -g staff -m 0755 "${home}/Library/Developer/CoreSimulator"
  install -m 0644 -o "$user" -g staff "$SRC" "$dst"
done
