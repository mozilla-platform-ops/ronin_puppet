# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_generic_worker::livelog {

    require win_generic_worker::directories

    file { $win_generic_worker::livelog_exe:
            source => $win_generic_worker::livelog_exe_source,
    }
    win_firewall::open_local_port { 'livelog_get':
        port            => $win_generic_worker::liveloggetport,
        remote_ip       => 'any',
        reciprocal      => false,
        fw_display_name => 'LiveLogGet',
    }
    win_firewall::open_local_port { 'livelog_put':
        port            => $win_generic_worker::livelogputport,
        remote_ip       => 'any',
        reciprocal      => false,
        fw_display_name => 'LiveLogPut',
    }
}
