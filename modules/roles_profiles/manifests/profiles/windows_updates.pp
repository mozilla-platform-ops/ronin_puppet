# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_updates {

    # This is temporary. Updates should be manged by WSUS.
    case $::operatingsystem {
        'Windows': {
            if $facts['custom_win_location'] == 'azure' {
                if $facts['custom_win_release_id'] == '1803' {
                    include win_updates::kb4486153
                    include win_updates::kb4494174
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
