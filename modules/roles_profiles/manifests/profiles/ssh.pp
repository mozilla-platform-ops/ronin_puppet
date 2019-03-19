# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ssh {

    case $::operatingsystem {
        'Windows': {

            $pwrshl_run_script    = lookup('win_pwrshl_run_script')
            $firewall_allowed_ips = lookup('win_dc_jumphosts')
            $ssh_program_data     = "${facts['custom_win_programdata']}\\ssh"
            $programfiles         = $facts['custom_win_programfiles']
            $firewall_port        = 22
            $firewall_rule_name   = 'SSH'

            class { 'win_openssh':
                programfiles      => $programfiles,
                pwrshl_run_script => $pwrshl_run_script,
                ssh_program_data  => $ssh_program_data,
            }
            case $facts['custom_win_mozspace'] {
                'mdc1', 'mdc2': {
                    win_firewall::open_local_port { "allow_${firewall_rule_name}":
                        port            => $firewall_port,
                        remote_ip       => $firewall_allowed_ips,
                        reciprocal      => true,
                        fw_display_name => $firewall_rule_name,
                    }
                }
                default : {
                    win_firewall::block_local_port { "block_${firewall_rule_name}":
                        fw_display_name => $firewall_rule_name,
                        port            => $firewall_port,
                    }
                }
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524440
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
