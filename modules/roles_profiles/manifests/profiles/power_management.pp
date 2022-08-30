# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::power_management {

    case $facts['os']['name'] {
        'Darwin': {
            include macos_mobileconfig_profiles::power_management
        }
        'Windows': {
            class { 'win_os_settings::power_scheme':
                ensure => 'High performance',
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524436
        }
        default: {
            fail("${$facts['os']['name']} not supported")
        }
    }
}
