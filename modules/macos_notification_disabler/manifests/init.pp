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
# lands squarely inside the fourth banner in the stack. One host accounted for
# 95 of that bug's 110 failures in 90 days.
#
# Scope and safety, after the first attempt at this had to be reverted:
#
#  * Nothing here writes into a TCC protected location. Puppet's ruby is denied
#    kTCCServiceSystemPolicyAllFiles (see macos_tcc_perms), so puppet -- invoked
#    by the org.mozilla.worker-runner LaunchDaemon, as root with no FDA grant --
#    cannot touch ~/Library/DoNotDisturb and friends. The previous version
#    managed the Focus assertion files there and failed with EPERM across the
#    production m4 pool. There is deliberately no DND layer above Big Sur now.
#
#  * Every script exits 0 unconditionally. run-puppet.sh greps the puppet log
#    for "^Error:" and mails a failure report per host per boot; on
#    reboot-per-task pools one failing resource is a mail flood and a
#    fleet-wide false red. Partial failures warn, degrade, and retry next boot.
#
#  * The uid-dependent work lives in shipped scripts that resolve it at run
#    time. cltbld's uid is NOT derivable from the OS version -- r8-97 and r8-90
#    are 36, r8-107 and r8-125 are 1025, the 14/15 hosts are 555 -- and getting
#    it wrong is silent.
class macos_notification_disabler (
  Boolean $enabled = true,
) {
  if $enabled {
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

    # The load-bearing resource: without the agents, no alerts are posted.
    # Writes /var/db/com.apple.xpc.launchd/disabled.<uid>.plist, because
    # `launchctl disable` alone takes effect immediately but is not persisted
    # and these hosts reboot once per task.
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

    # Clears whatever is already banked. Runs on every apply but only when
    # there is something to clear, so a clean host reports no change.
    exec { 'clear banked notifications for cltbld':
      command => '/usr/local/bin/clear_notification_store.sh',
      onlyif  => '/usr/local/bin/clear_notification_store.sh --count',
      path    => $exec_path,
      require => File['/usr/local/bin/clear_notification_store.sh'],
    }

    # Belt and braces on Catalina/Big Sur only; the script no-ops above that.
    # Must follow the clear, which also restarts NotificationCenter and would
    # otherwise race the DND write and win.
    exec { 'enable do not disturb for cltbld':
      command => '/usr/local/bin/enable_do_not_disturb.sh',
      unless  => '/usr/local/bin/enable_do_not_disturb.sh --check',
      path    => $exec_path,
      require => [
        File['/usr/local/bin/enable_do_not_disturb.sh'],
        Exec['clear banked notifications for cltbld'],
      ],
    }
  }
}
