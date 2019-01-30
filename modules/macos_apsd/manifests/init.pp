# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_apsd (
    Boolean $running = true
) {
    if $::operatingsystem == 'Darwin' {
        service { 'com.apple.apsd':
            ensure => $running,
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
