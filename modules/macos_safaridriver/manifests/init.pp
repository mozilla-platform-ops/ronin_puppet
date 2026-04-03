# @summary enable safaridriver on OS X systems
#   - safaridriver allows Selenium and other programs to control Safari
#
# @param user_running_safari The user who will be running Safari/safaridriver.
class macos_safaridriver (
  String $user_running_safari = 'cltbld',  # not fully parameterized, see below
) {
  $user_uid = $facts['cltbld_uid']

  case $facts['os']['name'] {
    'Darwin': {
      case $facts['os']['release']['major'] {
        '19','20','21','22','23','24': {
          $perm_script = '/usr/local/bin/add_tcc_perms.sh'
          $enable_script = '/usr/local/bin/safari-enable-remote-automation.sh'
          $tcc_script = '/usr/local/bin/tccutil.py'
          $safari_update_script = '/usr/local/bin/install_safari_softwareupdate_updates.py'

          file { $perm_script:
            content => file('macos_safaridriver/add_tcc_perms.sh'),
            mode    => '0755',
          }

          file { $enable_script:
            content => file('macos_safaridriver/safari-enable-remote-automation.sh'),
            mode    => '0755',
          }

          file { $safari_update_script:
            content => file('macos_safaridriver/install_safari_softwareupdate_updates.py'),
            mode    => '0755',
          }

          $semaphore_file = "/Users/${user_running_safari}/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"

          # Run perms script unless the semaphore exists. The semaphore is written
          # by add_tcc_perms.sh on success. We avoid querying TCC.db here because
          # on macOS 14/15 with SIP, sqlite3 gets authorization denied when run
          # from the worker-runner LaunchAgent context (no Full Disk Access).
          if $facts['running_in_test_kitchen'] != 'true' {
            exec { 'execute perms script':
              command => $perm_script,
              user    => 'root',
              unless  => '/bin/test -f /var/tmp/semaphore/safari-tcc-perms-applied',
              require => File[$perm_script],
              # logoutput => true,
            }
          }

          # needs to be logged in as the user, doesn't work in CI (haven't rebooted yet)
          if $facts['running_in_test_kitchen'] != 'true' {
            if $facts['os']['release']['major'] in ['23', '24'] {
              # macOS 14/15: SIP is enabled on new hardware (e.g. M4 Mac Mini).
              # Running osascript via 'launchctl asuser sudo -u' does not grant full
              # GUI session access for accessibility, and the system TCC database is
              # read-only even to root. Instead, bootstrap a LaunchAgent that runs
              # osascript directly into cltbld's GUI session. The applescript handles
              # its own semaphore so it is idempotent.
              $applescript = '/usr/local/bin/safari-enable-remote-automation.applescript'
              # macOS 14/15 requires the plist to be in ~/Library/LaunchAgents/ for
              # launchctl bootstrap to succeed. The auto-load race (agent loading before
              # TCC entries exist) is mitigated by requiring Exec['execute perms script']
              # before this file is deployed, and by the applescript's semaphore check.
              $launchagent_plist = "/Users/${user_running_safari}/Library/LaunchAgents/com.mozilla.safari.enableautomation.plist"

              file { $applescript:
                content => file('macos_safaridriver/safari-enable-remote-automation.applescript'),
                mode    => '0755',
              }

              file { $launchagent_plist:
                ensure  => file,
                owner   => $user_running_safari,
                group   => 'staff',
                mode    => '0644',
                content => file('macos_safaridriver/com.mozilla.safari.enableautomation.plist'),
                require => [File[$applescript], Exec['execute perms script']],
              }

              exec { 'execute enable remote automation script':
                command => "/bin/bash -c 'if /bin/launchctl print gui/${user_uid}/com.mozilla.safari.enableautomation > /dev/null 2>&1; then /bin/launchctl kickstart -k gui/${user_uid}/com.mozilla.safari.enableautomation; else /bin/launchctl bootstrap gui/${user_uid} ${launchagent_plist}; fi; count=0; while [ \$count -lt 120 ] && ! /bin/bash -c \"test -f ${semaphore_file} && grep -q 1 ${semaphore_file}\"; do sleep 2; count=\$((count+2)); done; grep -q 1 ${semaphore_file}'",
                require => [File[$applescript], File[$launchagent_plist], Exec['execute perms script']],
                cwd     => "/Users/${user_running_safari}",
                unless  => "/bin/bash -c 'test -f ${semaphore_file} && grep -q 1 ${semaphore_file}'",
                timeout => 180,
                # logoutput => true,
              }
            } else {
              # macOS 10.15-13: typically deployed with SIP disabled; run directly
              # via launchctl asuser to get cltbld's session context.
              exec { 'execute enable remote automation script':
                command => "/bin/launchctl asuser ${user_uid} sudo -u ${user_running_safari} ${enable_script}",
                require => File[$enable_script],
                cwd     => "/Users/${user_running_safari}",
                unless  => "/bin/test -f ${semaphore_file}",
                # logoutput => true,
              }
            }
          }

          sudo::custom { 'allow_safari_updates':
            user    => 'cltbld',
            command => '/usr/local/bin/install_safari_softwareupdates.py',
          }

          $safaridriver_semaphore = '/var/tmp/semaphore/safaridriver-enabled'

          exec { 'enable safari driver':
            command => "/usr/bin/safaridriver --enable && /bin/mkdir -p /var/tmp/semaphore && /usr/bin/touch ${safaridriver_semaphore}",
            unless  => "/bin/test -f ${safaridriver_semaphore}",
          }

          # non-admin users need to be in _webdeveloper group for safaridriver to work
          #   - https://developer.apple.com/forums/thread/124461
          #   - if not, `safaridriver --diagnose` will complain with:
          #       'ERROR: safaridriver could not launch because it is not configured'
          #
          # dseditgroup preferred to dscl
          #   - https://superuser.com/questions/214004/how-to-add-user-to-a-group-from-mac-os-x-command-line
          #
          # TODO: pull out user as param, i.e. don't hardcode cltbld user
          $group = '_webdeveloper'
          exec { "${user_running_safari}_group_${group}":
            command => "/usr/sbin/dseditgroup -o edit -a ${user_running_safari} -t user ${group}",
            unless  => "/usr/bin/groups ${user_running_safari} | /usr/bin/grep -q -w ${group}",
            #require => User[$user_running_safari],
          }
        }
        default: {
          fail("${facts['os']['release']} not supported")
        }
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
