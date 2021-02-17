# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ssh {

    case $::operatingsystem {
        'Windows': {

            $pwrshl_run_script    = lookup('win_pwrshl_run_script')
            $mdc1_jumphosts       = lookup('windows.datacenter.mdc1.jump_hosts')
            $mdc2_jumphosts       = lookup('windows.datacenter.mdc2.jump_hosts')
            $ssh_program_data     = "${facts['custom_win_programdata']}\\ssh"
            $programfiles         = $facts['custom_win_programfiles']
            $firewall_port        = lookup('windows.datacenter.ports.ssh')
            $firewall_rule_name   = 'SSH'

            # Needs to be reworked for non datacenter windows workers workers
            # if $facts['custom_win_location'] == 'azure' :
                # class { 'win_openssh':
                    # programfiles      => $programfiles,
                    # pwrshl_run_script => $pwrshl_run_script,
                    # ssh_program_data  => $ssh_program_data,
                # }
            # }

            class { 'win_users::administrator::authorized_keys':
                relops_key => lookup('all_users.relops', Hash, {'strategy' => 'unique'}),
            }

            # For datacenter workers OpenSSH is enabled during deployment
            if $facts['custom_win_location'] == 'datacenter' {
                if $facts['custom_win_sshd'] == 'installed' {
                    include win_openssh::service
                }
                # Restrict SSH access in datacenters to jump hosts.
                win_firewall::open_local_port { "allow_${firewall_rule_name}_mdc1_jumphost":
                    port            => $firewall_port,
                    remote_ip       => $mdc1_jumphosts,
                    reciprocal      => true,
                    fw_display_name => "${firewall_rule_name}_mdc1",
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
