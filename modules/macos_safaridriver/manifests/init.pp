class macos_safaridriver {
  case $facts['os']['name'] {
    'Darwin': {
      $the_script = '/usr/local/bin/add-safari-permissions.sh'

      file { $the_script:
        content => file('macos_safaridriver/add-safari-permissions.sh'),
        mode    => '0755',
      }

      exec { 'execute script':
        command => $the_script,
        require => File[$the_script],
      }

      # non-admin users need to be in _webdeveloper group for safaridriver to work
      # if not, `safaridriver --diagnose` will complain with:
      #   'ERROR: safaridriver could not launch because it is not configured'.
      #
      # dseditgroup preferred to dscl
      #   - https://superuser.com/questions/214004/how-to-add-user-to-a-group-from-mac-os-x-command-line
      #
      # TODO: pull out user as param, i.e. don't hardcode cltbld user
      $group = ['_webdeveloper']
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
