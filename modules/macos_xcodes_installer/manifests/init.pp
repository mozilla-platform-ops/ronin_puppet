# @summary installs xcodes
#
#
class macos_xcodes_installer (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['name'] {
      'Darwin': {
        $xcodes_installer_script = '/usr/local/bin/xcodes_installer.sh'

        file { $xcodes_installer_script:
          content => file('macos_xcodes_installer/xcodes_installer.sh'),
          mode    => '0755',
        }

        exec { 'execute xcodes installer script':
          command => $xcodes_installer_script,
          require => File[$xcodes_installer_script],
          user    => 'root',
        }
      }
    default: {
      fail("${facts['os']['release']} not supported")
    }
  }
  }
}
