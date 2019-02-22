# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::fw_exception {

    require win_openssh::install

    windows_firewall::exception { 'ssh':
        ensure       => present,
        direction    => 'in',
        action       => 'allow',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => 22,
        display_name => 'ssh in',
        description  => 'Openssh In',
    }
}
