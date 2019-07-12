# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This profile will include both KMS and WSUS
# KMS portions will continue to grow as support is added for additional platforms

class roles_profiles::profiles::microsoft_network_services {

    case $::operatingsystem {
        'Windows': {
            include win_kms
            # Bug List
            # kms
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1510828
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
