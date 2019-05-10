# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::telegraf (
    String $worker_type,
) {

    influx_url             = 'https://telegraf.relops.mozops.net'
    influx_database        = 'relops'
    influx_username        = 'relops_wo'
    influx_password        = lookup('influx_password')
    interval               = '60s'
    hostname               = $facts[hostname]
    fqdn                   = $facts['networking']['fqdn']
    workerGroup            = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1'),
    dataCenter             = $workerGroup
    workerType             = $worker_type

    telegraf_config_source = template('telegraf/telegraf.conf.erb')

    case $::operatingsystem {
        'Windows': {

            class { 'win_packages::telegraf':
                telegraf_config_source => $telegraf_config_source
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
