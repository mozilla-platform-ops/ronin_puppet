# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::configuration {

    require win_nxlog::install

    $log_aggregator = $win_nxlog::log_aggregator
    $conf_file      = $win_nxlog::conf_file

    file { "${win_nxlog::nxlog_dir}\\conf\\nxlog.conf":
        #content => epp("win_nxlog/${conf_file}.epp"),
        content => epp('win_nxlog/datacenter_base_nxlog.conf.epp'),
    }
}
