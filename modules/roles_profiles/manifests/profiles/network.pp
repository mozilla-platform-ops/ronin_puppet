# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::network {

    case $facts['os']['name'] {
        'Darwin': {
            include ::macos_utils::wifi_disabled
            include ::macos_utils::bonjour_advertisements_disabled
        }
        'Windows': {

            $net_category = 'private'
            if $facts['custom_win_net_category'] != $net_category {
                win_network::set_network_category { 'private_network':
                    network_category => $net_category,
                }
            }
            include win_network::disable_ipv6
            # Bug list
            # Network category
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1563287
            # ipv6
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1671022
        }
        default: {
            fail("${$facts['os']['name']} not supported")
        }
    }


}
