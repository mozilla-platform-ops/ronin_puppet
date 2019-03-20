# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_firewall::block_local_port (
    String  $fw_display_name,
    Integer $port,
    Boolean $reciprocal,
    String $remote_ip = 'any',
) {

    # Resource from puppet-windows_firewall

    windows_firewall::exception { "block_${fw_display_name}_in":
        ensure       => present,
        direction    => 'in',
        action       => 'block',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => $port,
        remote_ip    => '$remote_ip',
        display_name => "${fw_display_name}_IN",
        description  => "BLOCKED ${fw_display_name} in. [${port}]",
    }
    if $reciprocal {
        windows_firewall::exception { "block_${fw_display_name}_out":
            ensure       => present,
            direction    => 'out',
            action       => 'block',
            enabled      => true,
            protocol     => 'TCP',
            local_port   => $port,
            remote_ip    => 'any',
            display_name => "${fw_display_name}_OUT",
            description  => "BLOCKED ${fw_display_name} out. [${port}]",
        }
    }
}
