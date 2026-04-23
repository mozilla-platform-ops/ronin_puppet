# @summary removes people that have exited relops
#
#
class macos_people_remover (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['name'] {
      'Darwin': {
        $remover_script = '/usr/local/bin/user_cleanup.sh'

        file { $remover_script:
          content => file('macos_people_remover/user_cleanup.sh'),
          mode    => '0755',
        }

        exec { 'execute people remover script':
          command => $remover_script,
          path    => ['/bin', '/usr/bin'],
          unless  => 'sh -c \'for u in dhouse jwatkins mgoossens rthijssen andrej michelle; do [ -d /Users/$u ] && exit 1; done; exit 0\'',
          require => File[$remover_script],
          user    => 'root',
        }
      }
    default: {
      fail("${facts['os']['release']} not supported")
    }
  }
  }
}
