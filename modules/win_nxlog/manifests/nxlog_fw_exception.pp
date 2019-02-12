# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::nxlog_fw_exception {

    require win_nxlog::nxlog_intsall

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
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
