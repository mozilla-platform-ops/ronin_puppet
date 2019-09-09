# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::google_chrome {

    case $::operatingsystem {
        'Windows': {
            include win_packages::chrome
        }
        # Bug  list
        # https://bugzilla.mozilla.org/show_bug.cgi?id=1570767
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
