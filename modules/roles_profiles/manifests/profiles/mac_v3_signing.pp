# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mac_v3_signing {

    case $::operatingsystem {
        'Darwin': {

            include puppet::atboot

            # we can add generic-worker setup here like in gecko_t_osx_1014_generic_worker.pp

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
