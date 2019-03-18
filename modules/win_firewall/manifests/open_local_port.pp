# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_firewall::open_local_port (
String  $display_name,
Integer $port,
String $remote_ip,
Boolean $reciprocal = false,
){

    # Resource from puppet-windows_firewall

    windows_firewall::exception { "allow_${display_name}_in":
        ensure       => present,
        direction    => 'in',
        action       => 'allow',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => $port,
        remote_ip    => 'any',
        display_name => $display_name,
        description  => "ALLOWED ${display_name} in. [${port}]",
    }
    if ($reciprocal = true) {
        windows_firewall::exception { "allow_${display_name}_out":
            ensure       => present,
            direction    => 'out',
            action       => 'allow',
            enabled      => true,
            protocol     => 'TCP',
            local_port   => $port,
            remote_ip    => 'any',
            display_name => $display_name,
            description  => "ALLOWED ${display_name} out. [${port}]",
        }
    }
}
