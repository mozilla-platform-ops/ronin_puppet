# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::nxlog {

    case $::operatingsystem {
        'Windows': {
            require  win_packages::nxlog

            $programfilesx86 = $facts['programfilesx86']

            file { "${programfilesx86}\\nxlog\\cert\\papertrail-bundle.pem":
                content => file('roles_profiles/windows/papertrail-bundle.pem'),
            }
            file { "${programfilesx86}\\nxlog\\conf\\nxlog.conf":
                content => epp('roles_profiles/windows/nxlog.conf.epp'),
            }
            service { 'nxlog':
                ensure    => running,
                subscribe => File["${programfilesx86}\\nxlog\\conf\\nxlog.conf"],
                restart   => true,
                require   => Package['NxLog-CE'],
            }
            windows_firewall::exception { 'nxlog':
                ensure       => present,
                direction    => 'out',
                action       => 'allow',
                enabled      => true,
                protocol     => 'TCP',
                local_port   => 514,
                display_name => 'papertrail 1',
                description  => 'Nxlogout. [TCP 514]',
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
