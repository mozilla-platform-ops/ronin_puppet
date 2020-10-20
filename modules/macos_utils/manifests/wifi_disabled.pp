# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::wifi_disabled {
    if $::operatingsystem == 'Darwin' {
        exec {
            'disable-wifi':
                command => '/usr/sbin/networksetup -setnetworkserviceenabled Wi-Fi off',
                unless  => '/usr/sbin/networksetup -getnetworkserviceenabled Wi-Fi | grep Disabled';
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
