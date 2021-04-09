# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_papertrail (
    String  $papertrail_host,  # e.g. logs5.papertrailapp.com
    Integer $papertrail_port,  # e.g. 11111
    Array   $systemd_units = [],  # optional, only show these units
    Array   $syslog_identifiers = [],  # optional, display these syslog identifiers also
) {
    case $::operatingsystem {
        'Ubuntu': {
            case $::operatingsystemrelease {
                '18.04': {
                    # only configure if required variables are set
                    if (! $papertrail_host.empty) and ($papertrail_port != -1) {

                        # nmap provides ncat
                        include linux_packages::nmap

                        # NOTE: puppet 6.1+ will reload systemd automatically

                        # two papertrail systemd units:
                        # - one to tail journalctl (and optionally specific units)
                        # - an optional second to follow specific syslog topic/identifiers

                        # if systemd_units is empty, all journalctl logs will be sent
                        file { '/etc/systemd/system/papertrail.service':
                            mode    => '0644',
                            owner   => 'root',
                            group   => 'root',
                            content => template('linux_papertrail/papertrail.service.erb'),
                            notify  => Service['papertrail'],
                        }

                        service {
                            'papertrail':
                                ensure   => running,
                                provider => 'systemd',
                                enable   => true,
                                require  => Package['nmap'];
                        }

                        # if syslog_identifiers are empty, we don't need a second instance
                        if ! $syslog_identifiers.empty {

                            file { '/etc/systemd/system/papertrail-syslog.service':
                                mode    => '0644',
                                owner   => 'root',
                                group   => 'root',
                                content => template('linux_papertrail/papertrail-syslog.service.erb'),
                                notify  => Service['papertrail-syslog'],
                            }

                            service {
                                'papertrail-syslog':
                                    ensure   => running,
                                    provider => 'systemd',
                                    enable   => true,
                                    require  => Package['nmap'];
                            }
                        }
                        # TODO: handle else (remove unit file and stop service)
                    }
                    else {
                        warning ( 'host and port not set, not configuring' )
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
