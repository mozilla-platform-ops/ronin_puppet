# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_firewall::block_local_port (
String  $display_name,
Integer $port
){

    # Resource from puppet-windows_firewall

    windows_firewall::exception { "block_${display_name}_in":
        ensure       => present,
        direction    => 'in',
        action       => 'block',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => $port,
        remote_ip    => 'any',
        display_name => $display_name,
        description  => "BLOCK ${display_name} in. [${port}]",
    }
}
