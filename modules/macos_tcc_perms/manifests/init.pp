# @summary adds tcc permissions for bash/terminal screen recording
#
#
class macos_tcc_perms (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['name'] {
      'Darwin': {
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
    default: {
      fail("${facts['os']['release']} not supported")
    }
  }
  }
}
