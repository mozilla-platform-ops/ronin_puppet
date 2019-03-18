# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_firewall::mozilla_datacenter_ssh (
Integer $port,
String $allowed_ips
){

    require win_openssh::install

    # Resource from puppet-windows_firewall
    windows_firewall::exception { 'SSH_in':
        ensure       => present,
        direction    => 'in',
        action       => 'allow',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => $port,
        remote_ip    => $allowed_ips,
        display_name => 'SSH in',
        description  => "SSH in. [${win_openssh::port}]",
    }
    windows_firewall::exception { 'SSH_out':
        ensure       => present,
        direction    => 'out',
        action       => 'allow',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => $port,
        remote_ip    => $allowed_ips,
        display_name => 'SSH out',
        description  => "SSH out. [${win_openssh::port}]",
    }
}
