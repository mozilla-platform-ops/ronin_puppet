# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::set_desktop_background {

    file { "mac_desktop_image.py":
        content => file('mac_desktop_image.py'),
    }

    if $::operatingsystem == 'Darwin' {
        exec { 'execute python script to apply macos desktop background':
            command => '/usr/bin/python mac_desktop_image.py -s /Library/Desktop\ Pictures/Solid\ Colors/Teal.png',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
