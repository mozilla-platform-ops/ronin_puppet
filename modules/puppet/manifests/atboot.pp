# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class puppet::atboot (
    String $telegraf_user,
    String $telegraf_password,
    Optional[String] $puppet_env = 'aerickson',
    String $puppet_repo          = 'https://github.com/aerickson/ronin_puppet.git',
    String $puppet_branch        = 'boostrap_real_solution',
    String $puppet_notify_email  = 'aerickson@mozilla.com',
    String $smtp_relay_host      = 'localhost',
    Hash $meta_data              = {},
) {

    include puppet::setup

    case $::operatingsystem {
        'Darwin': {
            file {
                '/Library/LaunchDaemons/com.mozilla.atboot_puppet.plist':
                    owner  => 'root',
                    group  => 'wheel',
                    mode   => '0644',
                    source => 'puppet:///modules/puppet/org.mozilla.atboot_puppet.plist';

                '/usr/local/bin/run-puppet.sh':
                    owner   => 'root',
                    group   => 'wheel',
                    mode    => '0755',
                    content => template('puppet/puppet-darwin-run-puppet.sh.erb');
            }
        }
        'Ubuntu': {
            case $::operatingsystemrelease {
                '18.04': {
                    include linux_packages::puppet

                    # On Ubuntu 18.04 puppet runs by systemd and on successful result
                    # notifies dependent services
                    file {
                        '/lib/systemd/system/run-puppet.service':
                            owner   => 'root',
                            group   => 'root',
                            source  => 'puppet:///modules/puppet/puppet.service',
                            notify  => Exec['reload systemd'],
                            require => Class['linux_packages::puppet'];
                        '/usr/local/bin/run-puppet.sh':
                            owner   => 'root',
                            group   => 'root',
                            mode    => '0755',
                            content => template('puppet/puppet-ubuntu-run-puppet.sh.erb');
                    }
                    # reload systemd daemon
                    exec {
                        'reload systemd':
                            command => '/bin/systemctl daemon-reload';
                    }
                    # enable the run-puppet service
                    service {
                        'run-puppet':
                            enable   => true,
                            provider => 'systemd',
                            require  => File['/lib/systemd/system/run-puppet.service'];
                    }
                    # disable the deb provided service
                    service {
                        'puppet':
                            enable   => false,
                            provider => 'systemd';
                    }
                }
                default: {
                    fail("puppet::atboot support missing for ${::operatingsystemrelease}")
                }
            }
        }
        default: {
            fail("${module_name} does not support ${::operatingsystem}")
        }
    }

}
