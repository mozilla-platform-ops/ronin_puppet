# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging {

    case $::operatingsystem {
        'Windows': {

            include win_nxlog::nxlog_intsall
            include win_nxlog::nxlog_conf
            include win_nxlog::nxlog_service
            include win_nxlog::nxlog_fw_exception
            if $facts['location'] == 'aws' {
                include win_nxlog::nxlog_cert
            }

            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
