# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class grub (
    # dhouse is testing grub logging, but not working yet
    $log_aggregator_host = 'log-aggregator2.srv.releng.mdc2.mozilla.com',
    $log_aggregator_port = 514,
){
    case $::operatingsystem {
        'Ubuntu': {
            case $::operatingsystemrelease {
                '18.04': {
                    package {
                        'grub2-common':
                            ensure => present;
                    }
                    file {
                        '/etc/default/grub':
                            ensure  => present,
                            content => template('grub/default-grub.erb'),
                            notify  => Exec['update-grub'];
                    }
                    exec { 'update-grub':
                        command     => '/usr/sbin/update-grub',
                        subscribe   => File['/etc/default/grub'],
                        refreshonly => true,
                    }
                }
                default: {
                    fail("cannot install on ${::operatingsystemrelease}")
                }
            }
        }
        default: {
            fail("cannot install on ${::operatingsystem}")
        }
    }
}
