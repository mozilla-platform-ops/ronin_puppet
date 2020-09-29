# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Set up locale settings
class locale() {
    case $::operatingsystem {
        'Ubuntu': {
            file {
                '/etc/default/locale':
                    source => 'puppet:///modules/locale/locale.ubuntu',
                    notify => [Exec['generate-locales'], Exec['reconfigure-locales']];
            }
            exec {
                'generate-locales':
                    command     => '/usr/sbin/locale-gen en_US.UTF-8',
                    refreshonly => true;
            }
            exec {
                'reconfigure-locales':
                    command     => '/usr/sbin/dpkg-reconfigure --frontend=noninteractive locales',
                    refreshonly => true;
            }
        }
        default: {
            notice("Don't know how to set up locale on ${::operatingsystem}.")
        }
    }
}
