# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class telegraf (
    Hash $global_tags  = {},
    Hash $agent_params = {},
    Hash $inputs       = {},
) {
    include shared

    require packages::telegraf

    $influxdb_url      = 'https://telegraf.relops.mozops.net'
    $influxdb_username = lookup('telegraf.user')
    $influxdb_password = lookup('telegraf.password')

    $base_agent_params = {
        'interval' => '300s',
        'round_interval' => true,
        'metric_batch_size' => 5000,
        'metric_buffer_limit' => 20000,
        'collection_jitter' => '0s',
        'flush_interval' => '120s',
        'flush_jitter' => '60s',
        'precision' => 's',
        'debug' => false,
        'quiet' => true,
        'logfile' => '',
        'omit_hostname' => false,
    }
    $agent_params = $base_agent_params + $agent_params

    $base_inputs = {
       temp => {},
       cpu => {
           interval => '60s',
           percpu => true,
           totalcpu => true,
           ## If true, collect raw CPU time metrics.
           collect_cpu_time => false,
           ## If true, compute and report the sum of all non-idle CPU states.
           report_active => false,
       },
       system => {},
       mem => {},
       swap => {},
       diskio => {},
       disk => {
           mount_points => ['/'],
       },
       puppetagent => {
           location => '/opt/puppetlabs/puppet/cache/state/last_run_summary.yaml',
       },
    }
    $inputs = $base_inputs + $inputs

    case $facts['os']['name'] {
        'Darwin': {

            file {
                default: * => $::shared::file_defaults;

                '/etc/telegraf':
                    ensure => 'directory';

                '/etc/telegraf/telegraf.d':
                    ensure => 'directory';

                '/etc/telegraf/telegraf.conf':
                    ensure  => present,
                    content => template('telegraf/telegraf.conf.erb'),
                    mode    => '0600';

                '/var/log/telegraf':
                    ensure => directory,
                    mode   => '0755';

                '/Library/LaunchDaemons/telegraf.plist':
                    ensure  => present,
                    content => template('telegraf/telegraf.plist.erb'),
                    mode    => '0644';
            }

            service { 'telegraf':
                ensure  => running,
                require => File['/Library/LaunchDaemons/telegraf.plist'],
                enable  => true,
            }

        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
