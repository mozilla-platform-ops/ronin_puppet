# @summary update safari on OS X systems
#   - updates safari to a specified version
#
class macos_safariupdate () {
  case $facts['os']['name'] {
    'Darwin': {
      $update_script = '/usr/local/bin/update_safari.sh'

      file { $update_script:
        content => file('macos_safariupdate/update_safari.sh'),
        mode    => '0755',
      }

      exec { 'execute safari update script':
        command => $update_script,
        require => File[$update_script],
        user    => 'root',
      }
    }
  default: {
    fail("${facts['os']['release']} not supported")
  }
  }
}
