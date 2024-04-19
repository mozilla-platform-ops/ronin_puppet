# @summary adds tcc permissions for bash/terminal screen recording
#
#
class macos_tcc_perms (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['release']['major'] {
      '19': {
        $tcc_script = '/usr/local/bin/tcc_perms.sh'

        file { $tcc_script:
          content => file('macos_tcc_perms/tcc_perms.sh'),
          mode    => '0755',
        }

        exec { 'execute tcc perms script':
          command => $tcc_script,
          require => File[$tcc_script],
          user    => 'root',
        }
      }
      '20': {
        $tcc_script = '/usr/local/bin/tcc_perms2.sh'

        file { $tcc_script:
          content => file('macos_tcc_perms/tcc_perms2.sh'),
          mode    => '0755',
        }

        exec { 'execute tcc perms2 script':
          command => $tcc_script,
          require => File[$tcc_script],
          user    => 'root',
        }
      }
      '23': {
        $tcc_script = '/usr/local/bin/tcc_perms3.sh'

        file { $tcc_script:
          content => file('macos_tcc_perms/tcc_perms3.sh'),
          mode    => '0755',
        }

        exec { 'execute tcc perms3 script':
          command => $tcc_script,
          require => File[$tcc_script],
          user    => 'root',
        }
      }
      default: {
            fail("${facts['os']['release']} not supported")
          }
  }
}
}
