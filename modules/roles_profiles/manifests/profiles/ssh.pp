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
            $allowed_ips       = lookup('networks.jumphosts')

            class { 'win_openssh':
                programfiles      => $programfiles,
                pwrshl_run_script => $pwrshl_run_script,
                ssh_program_data  => $ssh_program_data,
            }
            case $facts['custom_win_mozspace'] {
                'mdc1', 'mdc2': {
                    class { 'win_firewall::mozilla_datacenter_ssh':
                        port        => $port,
                        allowed_ips => $allowed_ips,
                    }
                }
                default : {
                    win_firewall::block_local_port { 'block_ssh_in':
                        display_name => 'ssh',
                        port         => $port,
                    }
                }
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
