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
# Disabling the agents that post them stops new ones arriving; this clears
# whatever is already banked so the fix takes effect without a reimage.
#
# Note on reachability: the Catalina store lives under DARWIN_USER_DIR
# (/var/folders/...), which root can always write. The macOS 13+ store moved
# into ~/Library/Group Containers, which may be TCC protected -- and puppet's
# ruby has no Full Disk Access grant. So on 13+ this may legitimately be unable
# to open the database. That is not an error: the agent disables prevent new
# alerts, and anything already banked clears at the next reimage.
#
# ALWAYS EXITS 0 -- see the note in disable_notification_agents.sh.

set -u

USER_NAME="cltbld"

COUNT_ONLY=0
if [ "${1:-}" = "--count" ]; then
  COUNT_ONLY=1
fi

if ! id "${USER_NAME}" >/dev/null 2>&1; then
  echo "clear_notification_store: no such user ${USER_NAME}, nothing to do"
  exit 0
fi

USER_UID="$(id -u "${USER_NAME}")"

DARWIN_USER_DIR="$(sudo -u "${USER_NAME}" getconf DARWIN_USER_DIR 2>/dev/null || true)"
CANDIDATES=()
[ -n "${DARWIN_USER_DIR}" ] && CANDIDATES+=("${DARWIN_USER_DIR}com.apple.notificationcenter/db2/db")
CANDIDATES+=("/Users/${USER_NAME}/Library/Group Containers/group.com.apple.usernoted/db2/db")

# --count reports (via exit status) whether there is anything clearable, so
# puppet stays idempotent on an already-clean host. An unreadable database
# counts as nothing to do, not as work pending -- otherwise the exec would run
# on every single apply on any host where the store is TCC protected.
if [ "${COUNT_ONLY}" -eq 1 ]; then
  for db in "${CANDIDATES[@]}"; do
    [ -f "${db}" ] || continue
    n="$(sqlite3 "${db}" 'select (select count(*) from displayed) + (select count(*) from record);' 2>/dev/null || echo 0)"
    case "${n}" in
      ''|*[!0-9]*) continue ;;
    esac
    [ "${n}" -gt 0 ] && exit 0
  done
  exit 1
fi

cleared=0
for db in "${CANDIDATES[@]}"; do
  [ -f "${db}" ] || continue
  before="$(sqlite3 "${db}" 'select count(*) from displayed;' 2>/dev/null || echo unknown)"
  ok=1
  for table in displayed delivered record requests snoozed; do
    sqlite3 "${db}" "delete from ${table};" >/dev/null 2>&1 || ok=0
  done
  if [ "${ok}" -eq 1 ]; then
    echo "clear_notification_store: cleared ${db} (displayed was ${before})"
    cleared=1
  else
    echo "clear_notification_store: could not write ${db} (likely TCC protected); skipping"
  fi
done

if [ "${cleared}" -eq 0 ]; then
  echo "clear_notification_store: nothing cleared for ${USER_NAME}"
  exit 0
fi

# usernoted owns the store; NotificationCenter owns the on-screen windows. Both
# are respawned by launchd. Safe here because puppet runs from
# org.mozilla.atboot_puppet (LaunchOnlyOnce, before the worker-start sentinel),
# so this never lands in the middle of a task.
launchctl asuser "${USER_UID}" killall usernoted >/dev/null 2>&1 || true
launchctl asuser "${USER_UID}" killall NotificationCenter >/dev/null 2>&1 || true

exit 0
