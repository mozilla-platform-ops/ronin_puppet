# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::configuration {

    require win_nxlog::install

    file { "${win_nxlog::nxlog_dir}\\conf\\nxlog.conf":
        content => $win_nxlog::conf_file,
    }
    file { "${win_nxlog::nxlog_dir}\\conf\\nxlog.txt":
        content => epp('win_nxlog/nxlog.txt.epp'),
    }
}
