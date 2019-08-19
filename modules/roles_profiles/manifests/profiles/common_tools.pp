# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::common_tools {

    case $::operatingsystem {
        'Windows': {
            include win_packages::process_debug
            include win_packages::jq
            include win_packages::gpg4win
            include win_packages::sevenzip
            include win_packages::sublimetxt
            if $facts['custom_win_location'] == 'aws' {
                include win_packages::nircmd
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1510837
            # nircmd
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1562042
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
