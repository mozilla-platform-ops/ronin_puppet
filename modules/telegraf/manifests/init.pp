# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class telegraf (
    Hash $global_tags = {},
) {

    include shared

    require packages::telegraf

    $influxdb_url      = 'https://telegraf.relops.mozops.net'
    $influxdb_username = lookup('telegraf.user')
    $influxdb_password = lookup('telegraf.password')

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
                require => File['/Library/LaunchDaemons/telegraf.plist'],
                enable  => true,
            }

        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
