#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Bug 1781629: stop the Apple agents that post alert-style notifications.
# Alerts, unlike banners, stay on screen until someone clicks them, which never
# happens on a headless CI worker -- they stack down the right-hand edge of the
# display and get read by any test that samples screen pixels.
#
# The task user's uid is NOT fixed across the fleet. Observed on the gecko-t
# macOS pools: r8-97 and r8-90 are 36, r8-107 and r8-125 are 1025. Hardcoding it
# writes a stray disabled.<uid>.plist for a user that does not exist and the
# disable silently does nothing, so it is resolved here at run time.

set -u

USER_NAME="cltbld"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

AGENTS=(
  com.apple.SoftwareUpdateNotificationManager # "Updates Available - restart to install"
  com.apple.appstoreagent                    # App Store "Updates Available"
  com.apple.commerce                         # App Store auto-update agent
  com.apple.touristd                         # "Get to Know Your Mac"
  com.apple.diskspaced                       # "Your disk is almost full"
)

if ! id "${USER_NAME}" >/dev/null 2>&1; then
  echo "disable_notification_agents: no such user ${USER_NAME}" >&2
  exit 0
fi

USER_UID="$(id -u "${USER_NAME}")"
OVERRIDES="/var/db/com.apple.xpc.launchd/disabled.${USER_UID}.plist"

if [ "${CHECK_ONLY}" -eq 1 ]; then
  # Exit 0 == already fully configured, so puppet's unless suppresses the run.
  for agent in "${AGENTS[@]}"; do
    plutil -p "${OVERRIDES}" 2>/dev/null | grep -q "\"${agent}\" => 1" || exit 1
    launchctl print-disabled "user/${USER_UID}" 2>/dev/null \
      | grep -q "\"${agent}\" => true" || exit 1
  done
  exit 0
fi

for agent in "${AGENTS[@]}"; do
  # Takes effect immediately, but launchctl does NOT write $OVERRIDES, so on its
  # own this is lost at the next reboot -- and these hosts reboot once per task.
  # Only the user/ domain is used: gui/<uid> is rejected with "Unrecognized
  # domain-target specifier" where cltbld has no addressable GUI session, and
  # both domains share the same override store.
  launchctl disable "user/${USER_UID}/${agent}" 2>/dev/null || true
  # This is what actually survives the reboot.
  /usr/bin/defaults write "${OVERRIDES}" "${agent}" -bool true
done

# `defaults write` creates the file 0600 when it did not already exist. Match the
# 0644 the imaged hosts carry.
chmod 644 "${OVERRIDES}"
chown root:wheel "${OVERRIDES}"

echo "disable_notification_agents: ${#AGENTS[@]} agents disabled for ${USER_NAME} (uid ${USER_UID})"
exit 0
