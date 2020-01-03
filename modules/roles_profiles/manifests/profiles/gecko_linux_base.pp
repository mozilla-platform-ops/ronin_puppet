# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_linux_base {

    case $::operatingsystem {
        'Ubuntu': {
            contain linux_packages::python2
            contain linux_packages::python3

            contain linux_packages::python2_zstandard
            contain linux_packages::python3_zstandard

            contain linux_packages::zstd
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
}
