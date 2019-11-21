# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class fluentd (
    String $worker_type,
    String $stackdriver_project  = '',
    String $stackdriver_keyid    = '',
    String $stackdriver_key      = '',
    String $stackdriver_clientid = '',
    String $syslog_host          = lookup('papertrail.host', {'default_value' => ''}),
    Integer $syslog_port         = lookup('papertrail.port', {'default_value' => 514}),
    String $mac_log_level        = 'default',
) {

    include shared

    case $facts['os']['name'] {
        'Darwin': {
            require packages::td_agent  # use treasure data's build

            # the agent config assumes these plugins are available:
            include packages::fluent_plugin_remote_syslog
            include packages::fluent_plugin_papertrail

            if $stackdriver_clientid != '' {
                include packages::fluent_plugin_google_cloud

                file {
                    default: * => $::shared::file_defaults;

                    '/etc/google':
                        ensure => 'directory';

                    '/etc/google/auth':
                        ensure => 'directory';

                    '/etc/google/auth/application_default_credentials.json':
                        ensure  => present,
                        content => template('fluentd/application_default_credentials.json.erb'),
                        mode    => '0600';
                }
            }

            file {
                default: * => $::shared::file_defaults;

                '/Library/LaunchDaemons/td-agent.plist':
                    ensure  => present,
                    content => template('fluentd/td-agent.plist.erb'),
                    mode    => '0644';

                '/etc/td-agent/td-agent.conf':
                    ensure  => present,
                    content => template('fluentd/fluentd.conf.erb'),
                    mode    => '0644';

                '/var/log/td-agent':
                    ensure => directory,
                    mode   => '0755';
            }

            service { 'td-agent':
                ensure  => running,
                enable  => true,
                require => File['/Library/LaunchDaemons/td-agent.plist'],
            }

        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
