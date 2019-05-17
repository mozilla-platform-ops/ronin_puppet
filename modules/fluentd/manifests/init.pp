# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class fluentd (
    String $worker_type,
) {

    case $facts['os']['name'] {
        'Darwin': {
            require packages::td_agent  # use treasure data's build

            # use google's plugin for output ot stackdriver
            include packages::fluent_plugin_google_cloud
            # td-agent.conf assumes this plugin is present

            file {
                '/Library/LaunchDaemons/td-agent.plist':
                    ensure  => present,
                    content => template('fluentd/td-agent.plist.erb'),
                    mode    => '0644',
                    owner   => $::root_user,
                    group   => $::root_group;

                '/etc/td-agent/td-agent.conf':
                    ensure  => present,
                    content => template('fluentd/fluentd.conf.erb'),
                    mode    => '0644',
                    owner   => $::root_user,
                    group   => $::root_group;

                '/var/log/td-agent':
                    ensure => directory,
                    mode   => '0755',
                    owner  => $::root_user,
                    group  => $::root_group;
            }

            service { 'td-agent':
                require => File['/Library/LaunchDaemons/td-agent.plist'],
                enable  => true,
            }

        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
