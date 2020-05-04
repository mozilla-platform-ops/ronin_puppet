# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::maas_region {

    case $::operatingsystem {
        'Ubuntu':{
            # include linux_packages::ubuntu_desktop
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
