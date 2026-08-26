# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Keeps macOS notifications off the screen of a test worker.
#
# Bug 1781629: a handful of Apple agents post *alert*-style notifications,
# which -- unlike banners -- stay on screen until someone clicks them. Nobody
# does that on a headless CI worker, so they stack down the right-hand edge of
# the display and are re-drawn at every login. Any test that samples screen
# pixels then reads notification chrome instead of its own output. On a
# 1280x1024 display the sample point that
# test_getUserMedia_basicScreenshare.html uses for the upper-right quadrant
# lands squarely inside the fourth banner in the stack.
#
# Three layers, because no single one is sufficient:
#   1. disable the agents that post the alerts     -- stops new ones arriving
#   2. turn off software update / App Store checks -- removes the trigger
#   3. Do Not Disturb                              -- catches anything else,
#                                                     including notifications
#                                                     raised by the tests
# plus a one-shot clear of the store, so hosts already carrying a stack of
# alerts recover without a reimage.
class macos_notification_disabler (
  Boolean $enabled = true,
) {
  if $enabled {
    $os_major = Integer($facts['os']['release']['major'])

    # Same split as macos_utils::suppress_keyboard_assistant.
    if $os_major <= 20 {
      $cltbld_uid = '36'
    } else {
      $cltbld_uid = '555'
    }

    $exec_path = ['/bin', '/usr/bin', '/sbin', '/usr/sbin']

    # Agents observed posting sticky alerts on the gecko-t macOS pools.
    $notification_agents = [
      'com.apple.SoftwareUpdateNotificationManager', # "Updates Available - restart to install"
      'com.apple.appstoreagent',                     # App Store "Updates Available"
      'com.apple.commerce',                          # App Store auto-update agent
      'com.apple.touristd',                          # "Get to Know Your Mac"
      'com.apple.diskspaced',                        # "Your disk is almost full"
    ]

    $overrides = "/var/db/com.apple.xpc.launchd/disabled.${cltbld_uid}.plist"

    # Two steps per agent, because `launchctl disable` alone is not enough:
    # verified on macmini-r8-97, it takes effect immediately (launchctl
    # print-disabled reports it) but does NOT write $overrides, so it is lost at
    # the next reboot -- and these hosts reboot once per task. Writing the
    # override plist ourselves is what makes it stick.
    #
    # Only the user/ domain is used. gui/<uid> is rejected with "Unrecognized
    # domain-target specifier" on hosts where cltbld has no addressable GUI
    # session (seen on r8-107), and the two domains share the same override
    # store anyway.
    $notification_agents.each |String $agent| {
      exec { "persist notification agent override ${agent}":
        command => "/usr/bin/defaults write ${overrides} ${agent} -bool true",
        unless  => "/usr/bin/plutil -p ${overrides} | /usr/bin/grep -q '\"${agent}\" => 1'",
        path    => $exec_path,
        notify  => Exec['normalize launchd override permissions'],
      }

      exec { "disable notification agent ${agent} in the running session":
        command => "/bin/launchctl disable user/${cltbld_uid}/${agent}",
        unless  => "/bin/launchctl print-disabled user/${cltbld_uid} | /usr/bin/grep -q '\"${agent}\" => true'",
        path    => $exec_path,
      }
    }

    # `defaults write` creates the file 0600 when it did not already exist
    # (r8-107 had no disabled.36.plist at all). Match the 0644 the imaged hosts
    # carry so nothing is surprised by it later.
    exec { 'normalize launchd override permissions':
      command     => "/bin/chmod 644 ${overrides}",
      refreshonly => true,
      path        => $exec_path,
    }

    # Remove the trigger for the two "Updates Available" alerts. Worker OS
    # patching is driven by us, never by the machine deciding on its own.
    $update_prefs = {
      '/Library/Preferences/com.apple.SoftwareUpdate.plist' => [
        'AutomaticCheckEnabled',
        'AutomaticDownload',
        'CriticalUpdateInstall',
      ],
      '/Library/Preferences/com.apple.commerce.plist'       => [
        'AutoUpdate',
      ],
    }

    $update_prefs.each |String $domain, Array[String] $keys| {
      $keys.each |String $key| {
        exec { "disable auto update pref ${domain} ${key}":
          command => "/usr/bin/defaults write ${domain} ${key} -int 0",
          unless  => "/bin/test x`/usr/bin/defaults read ${domain} ${key}` = x0",
          path    => $exec_path,
        }
      }
    }

    if $os_major <= 20 {
      # Catalina / Big Sur: Do Not Disturb is a ByHost preference. There is no
      # Focus framework and no ~/Library/DoNotDisturb, so the JSON files below
      # would be ignored.
      # Order matters. Writing the pref while NotificationCenter is running
      # silently loses it -- verified on r8-97, the key read back as 1 and was
      # 0 again a minute later. NotificationCenter has to be stopped first and
      # cfprefsd flushed afterwards; launchd respawns NotificationCenter and it
      # then picks up the new value.
      $dnd_domain = 'com.apple.notificationcenterui'
      $dnd_write  = "/usr/bin/sudo -u cltbld /usr/bin/defaults -currentHost write ${dnd_domain}"

      exec { 'enable do not disturb for cltbld':
        command => "/bin/launchctl asuser ${cltbld_uid} /usr/bin/killall NotificationCenter; \
                    /bin/launchctl asuser ${cltbld_uid} /usr/bin/killall usernoted; \
                    /bin/sleep 2; \
                    ${dnd_write} doNotDisturb -bool true; \
                    ${dnd_write} doNotDisturbDate -date '9999-01-01 00:00:00 +0000'; \
                    /usr/bin/sudo -u cltbld /usr/bin/killall cfprefsd; \
                    exit 0",
        unless  => "/usr/bin/sudo -u cltbld /usr/bin/defaults -currentHost read ${dnd_domain} doNotDisturb | /usr/bin/grep -q '^1$'",
        path    => $exec_path,
      }
    } else {
      # Monterey and later: DND is a Focus mode, asserted by the files in
      # ~/Library/DoNotDisturb/DB. A logout/login is needed for the assertion
      # to be picked up.
      file { '/Users/cltbld/Library/DoNotDisturb':
        ensure => 'directory',
        owner  => 'cltbld',
        group  => 'staff',
        mode   => '0755',
      }

      file { '/Users/cltbld/Library/DoNotDisturb/DB':
        ensure  => 'directory',
        owner   => 'cltbld',
        group   => 'staff',
        mode    => '0755',
        require => File['/Users/cltbld/Library/DoNotDisturb'],
      }

      $files = [
        'Assertions.json',
        'Metrics.json',
        'Settings.sqlite',
        'Settings.sqlite-shm',
      ]

      $files.each |String $file| {
        file { "/Users/cltbld/Library/DoNotDisturb/DB/${file}":
          ensure  => 'file',
          source  => "puppet:///modules/macos_notification_disabler/${file}",
          owner   => 'cltbld',
          group   => 'staff',
          mode    => '0644',
          require => File['/Users/cltbld/Library/DoNotDisturb/DB'],
        }
      }
    }

    file { '/usr/local/bin/clear_notification_store.sh':
      ensure => file,
      source => 'puppet:///modules/macos_notification_disabler/clear_notification_store.sh',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    # Runs on every puppet apply, but only when something is actually banked,
    # so a clean host reports no change.
    exec { 'clear banked notifications for cltbld':
      command => '/usr/local/bin/clear_notification_store.sh cltbld',
      onlyif  => '/usr/local/bin/clear_notification_store.sh --count cltbld',
      path    => $exec_path,
      require => File['/usr/local/bin/clear_notification_store.sh'],
    }
  }
}
