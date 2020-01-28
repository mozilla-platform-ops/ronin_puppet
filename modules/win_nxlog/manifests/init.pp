# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog (
    String $nxlog_dir,
    String $location,
    String $log_aws_access_key,
    String $log_aws_secret_key,
    String $aws_log_destination,
    STring $node_name,
    String $log_aggregator,
    String $conf_file
){
    if $::operatingsystem == 'Windows' {
        include win_nxlog::install
        include win_nxlog::fw_exception
        include win_nxlog::service
        include win_nxlog::configuration
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
