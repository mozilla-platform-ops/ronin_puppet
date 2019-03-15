# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ssh {

    case $::operatingsystem {
        'Windows': {

            $ssh_program_data  = "${facts['custom_win_programdata']}\\ssh"
            $programfiles      = $facts['custom_win_programfiles']
            $pwrshl_run_script = lookup('win_pwrshl_run_script')
            $port              = 22
            $mdc1_jh1          = lookup('win_mdc1_jh1_ip')
            $mdc1_jh2          = lookup('win_mdc1_jh2_ip')
            $mdc2_jh1          = lookup('win_mdc2_jh1_ip')
            $mdc2_jh2          = lookup('win_mdc2_jh2_ip')
            $jumphosts         = $facts['custom_win_mozspace'] ? {
                mdc1    => "${mdc1_jh1},${mdc1_jh2}",
                mdc2    => "${mdc2_jh1},${mdc2_jh2}",
                default => '0.0.0.0',
            }

            if $jumphosts == '0.0.0.0' {
                warning('Unable to determine jumphosts for this location!')
            }

            class { 'win_openssh':
                programfiles      => $programfiles,
                pwrshl_run_script => $pwrshl_run_script,
                ssh_program_data  => $ssh_program_data,
                port              => $port,
                jumphosts         => $jumphosts,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524440
            # TODO Add authorized keys to hiera
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
