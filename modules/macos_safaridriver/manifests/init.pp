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
        '19','20','21','22','23': {
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

          exec { 'execute perms script':
            command => $perm_script,
            require => File[$perm_script],
            user    => 'root',
            # logoutput => true,
            # TODO: only run if needed, use semaphore?
          }

          # needs to run as cltbld via launchctl or won't work
          exec { 'execute enable remote automation script':
            command => "/bin/launchctl asuser ${user_uid} sudo -u ${user_running_safari} ${enable_script}",
            require => File[$enable_script],
            cwd     => "/Users/${user_running_safari}",
            # semaphore and semaphore dir are created in script
            unless  => "/bin/test -f /Users/${user_running_safari}/Library/Preferences/semaphore/safari-enable-remote-automation-has-run",
            # logoutput => true,
          }

          sudo::custom { 'allow_safari_updates':
            user    => 'cltbld',
            command => '/usr/local/bin/install_safari_softwareupdates.py',
          }

          exec { 'enable safari driver':
            command => '/usr/bin/safaridriver --enable',
            # TODO: only run if needed, currently no good test... use semaphore?
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
