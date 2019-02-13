# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::service {

    require win_nxlog::install
    require win_nxlog::configuration

    service { 'nxlog':
        ensure    => running,
        subscribe => File["${win_nxlog::nxlog_dir}\\conf\\nxlog.conf"],
        restart   => true,
        require   => Package['NXLog-CE'],
    }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1527484
# This fails on 1st run but is OK on the second run
