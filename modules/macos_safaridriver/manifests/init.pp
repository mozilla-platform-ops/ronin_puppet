class macos_safaridriver {
  case $facts['os']['name'] {
    'Darwin': {
      $perm_script = '/usr/local/bin/add_tcc_perms.sh'
      $enable_script = '/usr/local/bin/safari-enable-remote-automation.sh'
      $tcc_script = '/usr/local/bin/tccutil.py'

      file { $perm_script:
        content => file('macos_safaridriver/add_tcc_perms.sh'),
        mode    => '0755',
      }

      file { $enable_script:
        content => file('macos_safaridriver/safari-enable-remote-automation.sh'),
        mode    => '0755',
      }

      file { $tcc_script:
        content => file('macos_safaridriver/tccutil.py'),
        mode    => '0755',
      }

      exec { 'execute perms script':
        command => $perm_script,
        require => File[$perm_script],
        user    => 'root',
        # logoutput => true,
      }

      # needs to run as cltbld via launchctl or won't work
      exec { 'execute enable remote automation script':
        # TODO: don't hardcode user id of cltbld
        command => "/bin/launchctl asuser 36 sudo -u cltbld ${enable_script}",
        require => File[$enable_script],
        # logoutput => true,
      }

      exec { 'enable safari driver':
        command => '/usr/bin/safaridriver --enable',
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
      exec { "cltbld_group_${group}":
        command => "/usr/sbin/dseditgroup -o edit -a cltbld -t user ${group}",
        unless  => "/usr/bin/groups cltbld | /usr/bin/grep -q -w ${group}",
        require => User['cltbld'],
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
