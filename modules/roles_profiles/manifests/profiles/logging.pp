# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging {

    case $::operatingsystem {
        'Windows': {

            $location        = $facts['locations']
            $programfilesx86 = $facts['custom_win_programfilesx86']

            class { 'win_nxlog':
                nxlog_dir => "${programfilesx86}\\nxlog",
                location  => $location,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
