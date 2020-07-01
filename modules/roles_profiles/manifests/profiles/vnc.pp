# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::vnc {

    case $::operatingsystem {
        'Windows': {

            $pw_hash              = lookup('win_vncpw_hash')
            $read_only_pw_hash    = lookup('win_readonly_vncpw_hash')
            $ini_file             = "${facts['custom_win_programfiles']}\\uvnc bvba\\UltraVNC\\ultravnc.ini"
            $package              = 'UltraVnc'
            $msi                  = 'UltraVnc_1223_X64.msi'
            $mdc1_jumphosts       = lookup('windows.datacenter.mdc1.jump_hosts')
            $mdc2_jumphosts       = lookup('windows.datacenter.mdc2.jump_hosts')
            $firewall_port        = lookup('windows.datacenter.ports.vnc')
            $firewall_name        = 'UltraVNC'

            class { 'win_ultravnc':
                package           => $package,
                msi               => $msi,
                ini_file          => $ini_file,
                pw_hash           => $pw_hash,
                read_only_pw_hash => $read_only_pw_hash
            }
            case $facts['custom_win_mozspace'] {
                # Restrict VNC access in datacenters to jump hosts.
                'mdc1', 'mdc2': {
                    win_firewall::open_local_port { "allow_${firewall_name}_mdc1_jumphost":
                        port            => $firewall_port,
                        remote_ip       => $mdc1_jumphosts,
                        reciprocal      => true,
                        fw_display_name => "${firewall_name}_mdc1",
                    }
                    win_firewall::open_local_port { "allow_${firewall_name}_mdc2_jumphost":
                        port            => $firewall_port,
                        remote_ip       => $mdc1_jumphosts,
                        reciprocal      => true,
                        fw_display_name => "${firewall_name}_mdc2",
                    }
                }
                default : {
                    # No restrictions by default. The UltraVNC install typical opens the needed port.
                }
            }
            # Bug List
            #
            # TODO Add 32 bit support
        }
        'Ubuntu': {
            $user = lookup('linux_vnc.user')
            $user_homedir = lookup('linux_vnc.user_homedir')
            $group = lookup('linux_vnc.group')
            $password = lookup('linux_vnc.password')

            class { 'linux_vnc':
                user         => $user,
                group        => $group,
                user_homedir => $user_homedir,
                password     => $password,
            }
        }
        'Darwin': {
            include macos_utils::enable_screensharing
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
