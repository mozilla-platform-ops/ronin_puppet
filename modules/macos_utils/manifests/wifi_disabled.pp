# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::wifi_disabled {
    if $::operatingsystem == 'Darwin' {
        if $::networking['en0'] {
            exec {
                'disable-wifi':
                    command => '/usr/sbin/networksetup -setairportpower en1 off',
                    unless  => "/usr/sbin/networksetup -getairportpower en1 | egrep 'Off'";
            }
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
