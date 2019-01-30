# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::bonjour_advertisements_disabled {
    if $::operatingsystem == 'Darwin' {
        macos_utils::defaults {
            'disable-bonjour-multicast-advertisements':
                domain => '/Library/Preferences/com.apple.mDNSResponder',
                key    => 'NoMulticastAdvertisements',
                value  => '1';
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
