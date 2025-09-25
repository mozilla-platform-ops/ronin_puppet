# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::timezone {

    case $::operatingsystem {
        'Darwin': {
            class { 'macos_timezone':
                timezone => 'GMT',
            }
        }
        'Ubuntu': {
            class { 'timezone':
                timezone   => 'UTC',
                rtc_is_utc => true,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
