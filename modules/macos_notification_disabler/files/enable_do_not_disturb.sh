#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Bug 1781629: blanket Do Not Disturb for the task user, so that anything we did
# not think to disable individually -- including notifications raised by the
# tests -- still never paints the screen.
#
# Catalina and Big Sur ONLY. On Monterey and later DND became a Focus mode whose
# assertion lives in ~/Library/DoNotDisturb/DB, which is TCC protected. Puppet's
# ruby is denied kTCCServiceSystemPolicyAllFiles (see macos_tcc_perms), so the
# puppet run cannot write there: it fails with EPERM on a lock file. It
# LOOKS writable if you test by running run-puppet.sh over ssh, because sshd IS
# granted SystemPolicyAllFiles and the access is attributed to it -- that is how
# this shipped broken once already. Granting puppet FDA would need an MDM PPPC
# payload, which is out of scope for puppet. So there is no DND layer above
# Big Sur; the agent disables in disable_notification_agents.sh are the fix, and
# this is only ever belt and braces.
#
# ALWAYS EXITS 0 -- see the note in disable_notification_agents.sh.

set -u

USER_NAME="cltbld"
DOMAIN="com.apple.notificationcenterui"

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "${OS_MAJOR}" -gt 11 ]; then
  echo "enable_do_not_disturb: macOS ${OS_MAJOR} uses Focus, not applicable"
  exit 0
fi

if ! id "${USER_NAME}" >/dev/null 2>&1; then
  echo "enable_do_not_disturb: no such user ${USER_NAME}, nothing to do"
  exit 0
fi

# uid is not fixed across the fleet -- see disable_notification_agents.sh.
USER_UID="$(id -u "${USER_NAME}")"

read_dnd() {
  sudo -u "${USER_NAME}" /usr/bin/defaults -currentHost read "${DOMAIN}" \
    doNotDisturb 2>/dev/null
}

if [ "${CHECK_ONLY}" -eq 1 ]; then
  [ "$(read_dnd)" = "1" ] && exit 0
  exit 1
fi

# Order matters. Writing the pref while NotificationCenter is running silently
# loses it -- verified on r8-97, where the key read back as 1 and was 0 again a
# minute later. Stop the owning processes first; launchd respawns them and they
# pick up the new value.
#
# Do NOT kill cfprefsd afterwards. `defaults write` hands the change to cfprefsd
# to persist asynchronously, and killing it can discard a write still in flight.
#
# The write is verified rather than assumed, because the loser of a race with
# NotificationCenter is the write, and a false success is invisible.
for attempt in 1 2 3; do
  launchctl asuser "${USER_UID}" killall NotificationCenter >/dev/null 2>&1 || true
  launchctl asuser "${USER_UID}" killall usernoted >/dev/null 2>&1 || true
  sleep 2

  sudo -u "${USER_NAME}" /usr/bin/defaults -currentHost write "${DOMAIN}" \
    doNotDisturb -bool true 2>/dev/null || true
  # Without a date far in the future macOS clears DND at the next day boundary.
  sudo -u "${USER_NAME}" /usr/bin/defaults -currentHost write "${DOMAIN}" \
    doNotDisturbDate -date "9999-01-01 00:00:00 +0000" 2>/dev/null || true

  sleep 3

  if [ "$(read_dnd)" = "1" ]; then
    echo "enable_do_not_disturb: ${USER_NAME} (uid ${USER_UID}) doNotDisturb=1 (attempt ${attempt})"
    exit 0
  fi
done

echo "enable_do_not_disturb: WARNING could not set doNotDisturb for ${USER_NAME} (uid ${USER_UID}); the agent disables are the load-bearing fix, will retry next run"
exit 0
