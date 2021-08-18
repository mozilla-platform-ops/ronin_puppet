# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class telegraf (
    Hash $global_tags  = {},
    Hash $agent_params = {},  # see merged defaults below
    Hash $inputs       = {},  # see merged defaults below
) {
    include shared

    require packages::telegraf

    $telegraf_conf       = '/etc/telegraf/telegraf.conf'
    $telegraf_stdout_log = '/var/log/telegraf/telegraf-stdout.log'
    $telegraf_stderr_log = '/var/log/telegraf/telegraf-stderr.log'
    macos_utils::logrotate { 'telegraf-stderr-logs':
        path             => $telegraf_stderr_log,
    }
    macos_utils::logrotate { 'telegraf-stdout-logs':
        path             => $telegraf_stdout_log,
    }

    $influxdb_url        = lookup('telegraf.host')
    $influxdb_username   = lookup('telegraf.user')
    $influxdb_password   = lookup('telegraf.password')

    $syslog_host         = lookup('papertrail.host', {'default_value' => ''})
    $syslog_port         = lookup('papertrail.port', {'default_value' => 514})

    $worker_data_dir     = lookup('worker.data_dir', {'default_value' => '/opt/worker'})

    # Merge full hash of defaults for agent and input plugins.
    $_agent_params = {
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
    } + $agent_params

    $_inputs = {
        system => {},
        mem => {},
        swap => {},
        disk => {
            mount_points => ['/'],
        },
        puppetagent => {
            location => $facts['os']['name'] ? {
                'Darwin' => '/opt/puppetlabs/puppet/public/last_run_summary.yaml',
                default  => '/var/lib/puppet/state/last_run_summary.yaml',
            },
        },
    } + $inputs

    case $facts['os']['name'] {
        'Darwin': {

            file {
                default: * => $::shared::file_defaults;

                '/etc/telegraf':
                    ensure => 'directory';

                '/etc/telegraf/telegraf.d':
                    ensure => 'directory';

                $telegraf_conf:
                    ensure  => present,
                    content => template('telegraf/telegraf.conf.erb'),
                    mode    => '0644';

                '/etc/telegraf/telegraf.d/in.macos.log.conf':
                    ensure  => present,
                    content => template('telegraf/in.macos.log.conf.erb'),
                    mode    => '0644';

                '/etc/telegraf/telegraf.d/in.taskcluster.log.conf':
                    ensure  => present,
                    content => template('telegraf/in.taskcluster.log.conf.erb'),
                    mode    => '0644';

                '/etc/telegraf/papertrail-bundle.pem':
                    ensure  => present,
                    content => file('telegraf/papertrail-bundle.pem'),
                    mode    => '0600';

                '/etc/telegraf/telegraf.d/out.papertrail.conf':
                    ensure  => present,
                    content => template('telegraf/out.papertrail.conf.erb'),
                    mode    => '0600';

                '/etc/telegraf/telegraf.d/out.influxdb.conf':
                    ensure  => present,
                    content => template('telegraf/out.influxdb.conf.erb'),
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
