# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_kms::fw_exception {

    if $facts['custom_win_location'] == 'datacenter'or 'aws' {
        # Resources from puppet-windows_firewall
        windows_firewall_rule { 'KMS_in':
            ensure       => present,
            direction    => 'inbound',
            action       => 'allow',
            enabled      => true,
            protocol     => 'tcp',
            local_port   => 1688,
            remote_port  => 'any',
            display_name => 'Allow KMS in',
            description  => 'Windows authentication',
        }
        windows_firewall_rule { 'KMS_out':
            ensure       => present,
            direction    => 'outbound',
            action       => 'allow',
            enabled      => true,
            protocol     => 'tcp',
            local_port   => 1688,
            remote_port  => 'any',
            display_name => 'Allow KMS out',
            description  => 'Windows authentication',
        }
    } else {
        fail("Windows nodes in ${facts['custom_win_location']} need to explicitly addressed")
    }
}
