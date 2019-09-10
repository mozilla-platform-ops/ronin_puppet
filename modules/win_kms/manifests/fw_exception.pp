# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_kms::fw_exception {

    if $facts['custom_win_location'] == 'datacenter'or 'aws' {
        # Resources from puppet-windows_firewall
        windows_firewall::exception { 'KMS_in':
            ensure       => present,
            direction    => 'in',
            action       => 'allow',
            enabled      => true,
            protocol     => 'TCP',
            local_port   => 1688,
            remote_port  => 'any',
            display_name => 'Allow KMS in',
            description  => 'Windows authentication',
        }
        windows_firewall::exception { 'KMS_out':
            ensure       => present,
            direction    => 'out',
            action       => 'allow',
            enabled      => true,
            protocol     => 'TCP',
            local_port   => 1688,
            remote_port  => 'any',
            display_name => 'Allow KMS out',
            description  => 'Windows authentication',
        }
    } else {
        fail("Windows nodes in ${facts['custom_win_location']} need to explicitly addressed")
    }
}
