# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_firewall::open_local_port (
    String  $fw_display_name,
    Integer $port,
    Boolean $reciprocal,
) {

    # Resource from puppet-windows_firewall

    windows_firewall_rule { "allow_${fw_display_name}_in":
        ensure         => present,
        direction      => 'inbound',
        action         => 'allow',
        enabled        => true,
        protocol       => 'tcp',
        local_port     => $port,
        remote_address => 'any',
        display_name   => "${fw_display_name}_IN",
        description    => "ALLOWED ${fw_display_name} in. [${port}]",
    }
    if $reciprocal {
        windows_firewall_rule { "allow_${fw_display_name}_out":
            ensure         => present,
            direction      => 'outbound',
            action         => 'allow',
            enabled        => true,
            protocol       => 'tcp',
            local_port     => $port,
            remote_address => 'any',
            display_name   => "${fw_display_name}_OUT",
            description    => "ALLOWED ${fw_display_name} out. [${port}]",
        }
    }
}
