# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::network {

    case $::operatingsystem {
        'Darwin': {
            include ::macos_utils::wifi_disabled
            include ::macos_utils::bonjour_advertisements_disabled
        }
        'Windows': {
            include win_network::set_search_domain
            include win_network::disable_ipv6
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }


}
