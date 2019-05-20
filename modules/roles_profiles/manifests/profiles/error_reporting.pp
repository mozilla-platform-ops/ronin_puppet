# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::error_reporting {

    case $::operatingsystem {
        'Windows': {
            include win_os_settings::error_reporting

            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1562024
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1261812
        }
        default : {
            fail("${::operatingsystem} not supported")
        }
    }
}
