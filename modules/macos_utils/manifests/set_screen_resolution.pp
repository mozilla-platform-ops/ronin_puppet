# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::set_screen_resolution (
    Optional[String] $dimension = '1920',
) {
    if $::operatingsystem == 'Darwin' {
        exec { 'exec scres utility to set resolution':
            require => packages::scres,
            command => "/usr/local/bin/scres -s 0 ${dimension}",
            unless  => "system_profiler SPDisplaysDataType | grep ${dimension}",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
