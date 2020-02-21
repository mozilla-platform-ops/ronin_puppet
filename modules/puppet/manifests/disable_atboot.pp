# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class puppet::disable_atboot {

    case $::operatingsystem {
        'Darwin': {
            file {
                '/Library/LaunchDaemons/com.mozilla.atboot_puppet.plist':
                    ensure => absent;

                # default puppet service configuration
                '/Library/LaunchDaemons/com.puppetlabs.puppet.plist':
                    ensure => absent;

                # pxp-agent is disabled, but let's remove the plist also
                '/Library/LaunchDaemons/com.puppetlabs.pxp-agent.plist':
                    ensure => absent;
            }
        }
        default: {
            fail("${module_name} does not support ${::operatingsystem}")
        }
    }

}
