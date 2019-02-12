# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::nxlog_service {

    require win_packages::nxlog

    service { 'nxlog':
        ensure    => running,
        subscribe => File["${facts[custom_win_programfilesx86]}\\nxlog\\conf\\nxlog.conf"],
        restart   => true,
        require   => Package['NXLog-CE'],
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
