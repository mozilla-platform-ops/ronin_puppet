# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::disable_services {

    case $::operatingsystem {
        'Darwin': {
            class { 'macos_apsd':
                running => false,
            }
        }
        'Windows': {
            include win_disbale_services::disable_wsearch
            include win_disbale_services::disable_vss
            include win_disbale_services::disable_puppet
            include win_disbale_services::disable_windows_defender
            include win_disbale_services::disable_windows_update
            include win_disbale_services::disable_system_restore
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }


}
