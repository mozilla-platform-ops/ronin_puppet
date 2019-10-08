# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::fluent_plugin_papertrail {
    require packages::td_agent

    $version = '0.2.7'

    exec {
        'install papertrail plugin with agent ruby':
            path    => ['/bin', '/sbin', '/usr/sbin', '/usr/local/bin', '/usr/bin'],
            command => "/usr/sbin/td-agent-gem install fluent-plugin-papertrail --version ${version}",
            unless  => "test -f /opt/td-agent/embedded/lib/ruby/gems/2.4.0/gems/fluent-plugin-papertrail-${version}",
            require => Class['packages::td_agent'];
    }
}

