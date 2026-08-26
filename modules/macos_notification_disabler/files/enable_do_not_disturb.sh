#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Bug 1781629: blanket Do Not Disturb for the task user, so that anything we did
# not think to disable individually -- including notifications raised by the
# tests themselves -- still never paints the screen.
#
# Catalina and Big Sur only. Monterey introduced Focus, where the assertion
# lives in ~/Library/DoNotDisturb/DB and is managed declaratively by puppet.

set -u

USER_NAME="cltbld"
DOMAIN="com.apple.notificationcenterui"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

if ! id "${USER_NAME}" >/dev/null 2>&1; then
  echo "enable_do_not_disturb: no such user ${USER_NAME}" >&2
  exit 0
fi

# uid is not fixed across the fleet -- see disable_notification_agents.sh.
USER_UID="$(id -u "${USER_NAME}")"

read_dnd() {
  sudo -u "${USER_NAME}" /usr/bin/defaults -currentHost read "${DOMAIN}" doNotDisturb 2>/dev/null
}

if [ "${CHECK_ONLY}" -eq 1 ]; then
  [ "$(read_dnd)" = "1" ] && exit 0
  exit 1
fi

# Order matters. Writing the pref while NotificationCenter is running silently
# loses it -- verified on r8-97, where the key read back as 1 and was 0 again a
# minute later. Stop the owning processes first, write, then flush cfprefsd.
# launchd respawns both and they pick up the new value.
launchctl asuser "${USER_UID}" killall NotificationCenter >/dev/null 2>&1 || true
launchctl asuser "${USER_UID}" killall usernoted >/dev/null 2>&1 || true
sleep 2

sudo -u "${USER_NAME}" /usr/bin/defaults -currentHost write "${DOMAIN}" \
  doNotDisturb -bool true
# Without a date far in the future macOS clears DND at the next day boundary.
sudo -u "${USER_NAME}" /usr/bin/defaults -currentHost write "${DOMAIN}" \
  doNotDisturbDate -date "9999-01-01 00:00:00 +0000"

sudo -u "${USER_NAME}" killall cfprefsd >/dev/null 2>&1 || true
sleep 3

echo "enable_do_not_disturb: ${USER_NAME} (uid ${USER_UID}) doNotDisturb=$(read_dnd)"
exit 0
