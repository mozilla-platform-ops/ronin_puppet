# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::packages_installed {

    case $::operatingsystem {
        'Darwin': {
            $package_list = lookup('packages_classes', Array[String], 'unique', [])
            map ($package_list) | $package | { "packages::${package}" }.include
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }


}
