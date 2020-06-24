# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class log_aggregator::client {
    include ::config

    $log_aggregator = $::config::log_aggregator
    $logging_port   = $::config::logging_port

    # if (!$is_log_aggregator_host and $log_aggregator and $logging_port) {
    #     case $::operatingsystem {
    #         Ubuntu: {
    #             # TODO

    #             # rsyslog::config {
    #             #     # 'log_aggregator_client' : template("ubuntu_client.conf.erb")
    #             #         # contents => $::operatingsystemrelease ? {
    #             #             # '16.04' => template("${module_name}/ubuntu_client.conf.erb"),
    #             #             # default => template("${module_name}/client.conf.erb"),
    #             #         # }
    #             # }
    #         }
    #         default: {
    #             fail("Not supported on ${::operatingsystem}")
    #         }
    #     }
    # }
}
