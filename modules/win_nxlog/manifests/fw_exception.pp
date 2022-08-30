# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::fw_exception {

    require win_nxlog::install

    # Resource from puppet-windows_firewall
    windows_firewall_rule { 'nxlog':
        ensure       => present,
        direction    => 'outbound',
        action       => 'allow',
        enabled      => true,
        protocol     => 'tcp',
        local_port   => 514,
        display_name => 'papertrail 1',
        description  => 'Nxlogout. [TCP 514]',
    }
}
