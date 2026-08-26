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
# plus a clear of the store, so hosts already carrying a stack of alerts
# recover without a reimage.
#
# The uid-dependent work is done in shipped scripts rather than built up as
# strings here. cltbld's uid is NOT fixed across the fleet -- r8-97 and r8-90
# are 36, r8-107 and r8-125 are 1025 -- and getting it wrong is silent: you
# write a stray disabled.<uid>.plist for a user that does not exist and the
# disable does nothing at all.
class macos_notification_disabler (
  Boolean $enabled = true,
) {
  if $enabled {
    $os_major  = Integer($facts['os']['release']['major'])
    $exec_path = ['/bin', '/usr/bin', '/sbin', '/usr/sbin']

    $scripts = [
      'disable_notification_agents.sh',
      'enable_do_not_disturb.sh',
      'clear_notification_store.sh',
    ]

    $scripts.each |String $script| {
      file { "/usr/local/bin/${script}":
        ensure => file,
        source => "puppet:///modules/macos_notification_disabler/${script}",
        owner  => 'root',
        group  => 'wheel',
        mode   => '0755',
      }
    }

    exec { 'disable notification agents':
      command => '/usr/local/bin/disable_notification_agents.sh',
      unless  => '/usr/local/bin/disable_notification_agents.sh --check',
      path    => $exec_path,
      require => File['/usr/local/bin/disable_notification_agents.sh'],
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
      # Focus framework and no ~/Library/DoNotDisturb, so the JSON files used
      # on later releases would simply be ignored.
      # Must come after the store clear: that also restarts NotificationCenter,
      # which races the DND write and wins.
      exec { 'enable do not disturb for cltbld':
        command => '/usr/local/bin/enable_do_not_disturb.sh',
        unless  => '/usr/local/bin/enable_do_not_disturb.sh --check',
        path    => $exec_path,
        require => [
          File['/usr/local/bin/enable_do_not_disturb.sh'],
          Exec['clear banked notifications for cltbld'],
        ],
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

      $dnd_files = [
        'Assertions.json',
        'Metrics.json',
        'Settings.sqlite',
        'Settings.sqlite-shm',
      ]

      $dnd_files.each |String $dnd_file| {
        file { "/Users/cltbld/Library/DoNotDisturb/DB/${dnd_file}":
          ensure  => 'file',
          source  => "puppet:///modules/macos_notification_disabler/${dnd_file}",
          owner   => 'cltbld',
          group   => 'staff',
          mode    => '0644',
          require => File['/Users/cltbld/Library/DoNotDisturb/DB'],
        }
      }
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
