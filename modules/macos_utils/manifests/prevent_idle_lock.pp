# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Keep a worker's interactive GUI session from ever locking itself (bug 2073762).
#
# A headless worker session receives no HID input, so IOHIDSystem's HIDIdleTime
# climbs monotonically from console login and is not reset by task activity. At
# com.apple.screensaver's default idleTime (1200s) the screen saver starts and
# the session locks. loginwindow then owns the front-most window, which nulls
# Services.focus.activeWindow, and any test harness that waits on a focus event
# hangs until its no-output timeout -- reftest's "application timed out after 370
# seconds with no output".
#
# Two independent belts, because neither alone is dependable:
#
#   1. A caffeinate LaunchAgent holding PreventUserIdleDisplaySleep for the life
#      of the session. Domain-independent and survives a re-clone, but relies on
#      the assertion continuing to gate the screen saver.
#   2. `defaults -currentHost write com.apple.screensaver idleTime 0`, run as the
#      session user inside its own launchd domain so cfprefsd does not discard
#      it. Authoritative when honoured, but -currentHost is keyed to the hardware
#      UUID -- that is exactly why the equivalent write baked into the macos-vms
#      image missed (it ran as the image-build admin, not as the task user).
#
# askForPassword is deliberately NOT set: it is MDM-managed on macOS 14+ and a
# `defaults` write to it is ignored. Preventing the screen saver from starting at
# all is what keeps the session unlocked.
class macos_utils::prevent_idle_lock (
  String  $user             = 'cltbld',
  Boolean $manage_launchagent = true,
  Boolean $manage_defaults    = true,
) {
  # cltbld's uid is not derivable from the OS release; it is 36 on the pre-Big Sur
  # roles and 555 everywhere current. Same branch as
  # macos_utils::suppress_keyboard_assistant so the two agents land in one domain.
  if Integer($facts['os']['release']['major']) <= 20 {
    $uid = '36'
  } else {
    $uid = '555'
  }

  $launchagent_dir  = "/Users/${user}/Library/LaunchAgents"
  $launchagent_path = "${launchagent_dir}/com.mozilla.prevent-idle-lock.plist"

  if $manage_launchagent {
    exec { 'create_prevent_idle_lock_launchagents_dir':
      command => "/bin/mkdir -p ${launchagent_dir}",
      creates => $launchagent_dir,
      path    => ['/bin'],
    }

    file { $launchagent_path:
      ensure  => file,
      owner   => $user,
      group   => 'staff',
      mode    => '0644',
      source  => 'puppet:///modules/macos_utils/com.mozilla.prevent-idle-lock.plist',
      require => Exec['create_prevent_idle_lock_launchagents_dir'],
    }

    # bootout then bootstrap so an edited plist is actually re-read; `launchctl
    # kickstart` only restarts the already-loaded job definition. Both are
    # tolerated failures: on a guest whose GUI session has not come up yet there
    # is no gui/<uid> domain to bootstrap into, and the next puppet run (these
    # guests re-apply on every boot) picks it up once there is.
    exec { 'load or restart prevent-idle-lock agent':
      command     => "/bin/bash -c '/bin/launchctl bootout gui/${uid}/com.mozilla.prevent-idle-lock 2>/dev/null; \
                    /bin/launchctl bootstrap gui/${uid} \"${launchagent_path}\" 2>/dev/null; exit 0'",
      path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
      refreshonly => true,
      subscribe   => File[$launchagent_path],
    }
  }

  if $manage_defaults {
    # Run inside the user's own launchd domain (`launchctl asuser`) rather than
    # via exec's `user` attribute. A bare `defaults write` from outside the
    # session talks to a different cfprefsd and the value can be silently
    # overwritten by the live session's cached copy.
    #
    # `unless` reads the value back the same way it is written, so this is a
    # no-op once converged. exit 0 because `defaults read` on an absent key
    # returns non-zero, which is the pre-fix state we want to correct.
    exec { 'disable screen saver for the worker session':
      command => "/bin/launchctl asuser ${uid} /usr/bin/sudo -u ${user} \
                /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 0",
      unless  => "/bin/bash -c '[ \"\$(/bin/launchctl asuser ${uid} /usr/bin/sudo -u ${user} \
                /usr/bin/defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null)\" = \"0\" ]'",
      path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
    }
  }
}
