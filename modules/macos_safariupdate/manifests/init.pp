# @summary update safari on OS X systems
#   - updates safari to a specified version
#
class macos_safariupdate () {
  case $facts['os']['name'] {
    'Darwin': {
      $update_script = '/usr/local/bin/update_safari.sh'
      # Root-owned semaphore (see update_safari.sh). Previously the script had
      # no unless/onlyif, so root re-ran it -- and its chown of a
      # cltbld-controlled directory -- on every converge.
      $semaphore_file = '/var/db/ronin-semaphores/safari-update-has-run'
      $semaphore_version = '2'

      file { $update_script:
        content => file('macos_safariupdate/update_safari.sh'),
        mode    => '0755',
      }

      exec { 'execute safari update script':
        command => $update_script,
        require => File[$update_script],
        user    => 'root',
        unless  => "/bin/bash -c 'test -f ${semaphore_file} && grep -qx ${semaphore_version} ${semaphore_file}'",
      }
    }
  default: {
    fail("${facts['os']['release']} not supported")
  }
  }
}
