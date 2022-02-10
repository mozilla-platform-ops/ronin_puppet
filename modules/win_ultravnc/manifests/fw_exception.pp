# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_ultravnc::fw_exception {

    require win_ultravnc::install

    # Resource from puppet-windows_firewall
    windows_firewall_rule { 'ultra':
        ensure       => present,
        direction    => 'inbound',
        action       => 'allow',
        enabled      => true,
        protocol     => 'tcp',
        local_port   => $win_ultravnc::port,
        remote_ip    => $win_ultravnc::jumphosts,
        display_name => 'UltraVNC in',
        description  => "UltraVNC. [${win_ultravnc::port}]",
    }
}
