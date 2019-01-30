# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::network {

    case $::operatingsystem {
        'Darwin': {
            include ::macos_utils::wifi_disabled
            include ::macos_utils::bonjour_advertisements_disabled
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }


}
