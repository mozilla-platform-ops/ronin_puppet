# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::audit_and_recovery {

    case $::operatingsystem {
        'Windows': {
            if ($facts['custom_win_location'] == 'datacenter') {
                include win_maintenance::moonshot_scripts
            } else {
                warning("workers associated with ${facts['custom_win_location']} location are not supported")
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
