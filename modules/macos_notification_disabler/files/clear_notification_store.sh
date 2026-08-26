#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Bug 1781629: alert-style macOS notifications persist on screen until a human
# clicks them. Nobody ever does on a headless CI worker, so they accumulate in
# the notification store's "displayed" table and are re-drawn down the right
# hand edge of the display on every login. Any test that samples screen pixels
# then reads notification chrome instead of the pixels it drew --
# test_getUserMedia_basicScreenshare.html is the one that noticed.
#
# Disabling the agents that post them (see init.pp) stops new ones arriving;
# this clears whatever is already banked so the fix takes effect without
# waiting for a reimage.

set -u

# --count reports (via exit status) whether there is anything to clear, so
# puppet can stay idempotent on an already-clean host.
COUNT_ONLY=0
if [ "${1:-}" = "--count" ]; then
  COUNT_ONLY=1
  shift
fi

USER_NAME="${1:-cltbld}"

if ! id "${USER_NAME}" >/dev/null 2>&1; then
  echo "clear_notification_store: no such user ${USER_NAME}" >&2
  exit 0
fi

USER_UID="$(id -u "${USER_NAME}")"

# The store moved out of the per-boot temp dir into a group container in macOS 13.
DARWIN_USER_DIR="$(sudo -u "${USER_NAME}" getconf DARWIN_USER_DIR 2>/dev/null || true)"
CANDIDATES=(
  "/Users/${USER_NAME}/Library/Group Containers/group.com.apple.usernoted/db2/db"
  "${DARWIN_USER_DIR}com.apple.notificationcenter/db2/db"
)

if [ "${COUNT_ONLY}" -eq 1 ]; then
  for db in "${CANDIDATES[@]}"; do
    [ -f "${db}" ] || continue
    n="$(sqlite3 "${db}" 'select (select count(*) from displayed) + (select count(*) from record);' 2>/dev/null || echo 0)"
    [ "${n:-0}" -gt 0 ] && exit 0
  done
  exit 1
fi

cleared=0
for db in "${CANDIDATES[@]}"; do
  [ -f "${db}" ] || continue
  before="$(sqlite3 "${db}" 'select count(*) from displayed;' 2>/dev/null || echo 0)"
  for table in displayed delivered record requests snoozed; do
    sqlite3 "${db}" "delete from ${table};" >/dev/null 2>&1 || true
  done
  echo "clear_notification_store: cleared ${db} (displayed was ${before})"
  cleared=1
done

if [ "${cleared}" -eq 0 ]; then
  echo "clear_notification_store: no notification store found for ${USER_NAME}"
  exit 0
fi

# usernoted owns the store; NotificationCenter owns the on-screen windows.
# Both are respawned by launchd. Only meaningful if the user has a GUI session.
launchctl asuser "${USER_UID}" killall usernoted >/dev/null 2>&1 || true
launchctl asuser "${USER_UID}" killall NotificationCenter >/dev/null 2>&1 || true

exit 0
