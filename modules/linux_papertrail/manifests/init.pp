# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_papertrail (
    String $papertrail_host,  # e.g. logs5.papertrailapp.com
    Integer $papertrail_port,  # e.g. 11111
    Array   $systemd_units = [],  # optional, only show these units
) {


    case $::operatingsystem {
        'Ubuntu': {
            case $::operatingsystemrelease {
                '18.04': {
                    # nmap provides ncat
                    include linux_packages::nmap

                    file { '/etc/systemd/system/papertrail.service':
                        mode    => '0644',
                        owner   => 'root',
                        group   => 'root',
                        content => template('linux_papertrail/papertrail.service.erb'),
                    }

                    # puppet 6.1+ will reload systemd automatically
                    service {
                        'papertrail':
                            ensure   => running,
                            provider => 'systemd',
                            enable   => true,
                            require  => Package['nmap'];
                    }

                }
                default: {
                    fail ("Cannot install on Ubuntu version ${::operatingsystemrelease}")
                }
            }
        }
        default: {
            fail("gui is not supported on ${::operatingsystem}")
        }
    }
}
