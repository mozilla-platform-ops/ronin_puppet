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
