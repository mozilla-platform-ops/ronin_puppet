# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::fluent_plugin_remote_syslog {
    require packages::td_agent

    $version = '1.0.0'

    exec {
        'install remote syslog plugin with agent ruby':
            path    => ['/bin', '/sbin', '/usr/sbin', '/usr/local/bin', '/usr/bin'],
            command => "/usr/sbin/td-agent-gem install fluent-plugin-remote_syslog --version ${version}",
            unless  => "test -e /opt/td-agent/embedded/lib/ruby/gems/2.4.0/gems/fluent-plugin-remote_syslog-${version}",
            require => Class['packages::td_agent'];
    }
}

