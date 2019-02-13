# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ssh {

    case $::operatingsystem {
        'Windows': {

            $ssh_program_data = "${facts['custom_win_programdata']}\\ssh"
            $programfiles     = $facts['custom_win_programfiles']
            $pwrshl_run_scrpt = lookup('win_pwrshl_run_scrpt')

            class { 'win_openssh':
                programfiles     => $programfiles,
                pwrshl_run_scrpt => $pwrshl_run_scrpt,
                ssh_program_data => $ssh_program_data,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524440
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
