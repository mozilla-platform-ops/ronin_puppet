# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class disable_services() {
    case $::operatingsystem {
        'Ubuntu': {
            # These packages are required by ubuntu-desktop, so we can't uninstall them.
            # Instead, install but disable them.
            case $::operatingsystemrelease {
                '18.04': {
                    # acpi removed because it can't be disabled this way
                    #   (never worked in build-puppet/16.04)
                    $install_and_disable = [ 'cups', 'anacron',
                        'whoopsie', 'modemmanager', 'apport',
                        'avahi-daemon', 'network-manager' ]
                    package {
                        $install_and_disable:
                            ensure => latest;
                    }
                    service {
                        $install_and_disable:
                            ensure   => stopped,
                            provider => 'systemd',
                            enable   => false,
                            require  => Package[$install_and_disable];
                    }

                    # services we need to disable that depend of the above services
                    # NetworkManager-wait-online.service depends on network-manager.service
                    # avahi-daemon.service depends on cups-browsed.service
                    # cups-browsed.service depends on cups.service
                    $disable = ['cups-browsed']
                    service {
                        $disable:
                            ensure   => stopped,
                            provider => 'systemd',
                            enable   => false
                    }

                    # disable apport via defaults also
                    file {
                        '/etc/default/apport':
                            source => "puppet:///modules/${module_name}/apport";
                    }

                    # this package and service have different names
                    package {
                        'bluez':
                            ensure => latest;
                    }
                    service {
                        'bluetooth':
                            ensure   => stopped,
                            provider => 'systemd',
                            enable   => false,
                            require  => Package['bluez'];
                    }

                    # disable periodic apt actions
                    file {
                        '/etc/apt/apt.conf.d/10periodic':
                          ensure => file,
                          owner  => 'root',
                          group  => 'root',
                          source => "puppet:///modules/${module_name}/10periodic";

                        '/etc/apt/apt.conf.d/20auto-upgrades':
                          ensure => file,
                          owner  => 'root',
                          group  => 'root',
                          source => "puppet:///modules/${module_name}/20auto-upgrades";
                    }

                    # stop 'unattended-upgrades' processes, disabled in /etc/apt/apt.conf.d/20auto-upgrades
                    # but still showing up
                    service { 'unattended-upgrades':
                        ensure => stopped,
                        enable => false,
                    }
                }
                default: {
                    fail("Unrecognized Ubuntu version ${::operatingsystemrelease}")
                }
            }
        }
        default: {
            fail("gui is not supported on ${::operatingsystem}")
        }
    }
}
