# @summary adds tcc permissions for bash/terminal screen recording
#
#
class macos_tcc_perms (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['release']['major'] {
      '19','20','21','22','23', '24': {
        $tcc_script = '/usr/local/bin/tcc_perms.sh'

        file { $tcc_script:
          content => file('macos_tcc_perms/tcc_perms.sh'),
          mode    => '0755',
        }

        # cltbld's user TCC.db only exists after cltbld first logs in.
        # On fresh bootstrap (autologin set up but cltbld hasn't logged in
        # yet) we skip this resource — a reboot triggers autologin and the
        # next puppet apply will pick it up.
        if $facts['running_in_test_kitchen'] != 'true' and $facts['cltbld_tcc_db_present'] {
          exec { 'execute tcc perms script':
            command => $tcc_script,
            require => File[$tcc_script],
            user    => 'root',
          }
        }
      }
      default: {
        fail("${facts['os']['release']} not supported")
      }
    }
  }
}
