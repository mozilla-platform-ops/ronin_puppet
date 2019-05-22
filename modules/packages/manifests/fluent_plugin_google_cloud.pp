# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::fluent_plugin_google_cloud {
    require packages::td_agent

    $version = '0.7.11'

    # fluent-plugin-google-cloud requires json which expects coreutils (requires gnu mkdir)
    package { 'coreutils':
        ensure   => present,
        provider => brew,
    }

    exec {
        'install plugin with agent ruby':
            path    => ['/bin', '/sbin', '/usr/sbin', '/usr/local/bin', '/usr/bin'],
            command => "/usr/sbin/td-agent-gem install fluent-plugin-google-cloud --version ${version}",
            unless  => "test -f /opt/td-agent/embedded/lib/ruby/gems/2.4.0/gems/fluent-plugin-google-cloud-${version}",
            require => Class['packages::td_agent'];
    }
}

