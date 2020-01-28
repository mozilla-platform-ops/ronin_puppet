# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::log_to_s3 {

    require win_nxlog::install
    # Nxlog requires Python to send logs to S3
    # On Windows we get Pyhton from Mozilla Build

    $access_key = $win_nxlog::log_aws_access_key
    $secret_key = $win_nxlog::log_aws_secret_key
    $destination = $win_nxlog::aws_log_destination
    $name        = $win_nxlog::node_name

    file { "${win_nxlog::nxlog_dir}\\s3_write.py":
        content => epp('win_nxlog/s3_write.py.epp'),
    }
}
