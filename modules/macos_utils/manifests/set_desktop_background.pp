# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::set_desktop_background {

    file { "/usr/local/bin/mac_desktop_image.py":
        content => file('macos_utils/mac_desktop_image.py'),
    }

    if $::operatingsystem == 'Darwin' {
        # su to get user desktop environment. exec's user option cannot do this
        exec { 'execute python script to apply macos desktop background':
            command => '/usr/bin/su - cltbld -c "/usr/bin/python /usr/local/bin/mac_desktop_image.py -v -s /Library/Desktop\ Pictures/Solid\ Colors/Teal.png"',
            require => File["/usr/local/bin/mac_desktop_image.py"],
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
