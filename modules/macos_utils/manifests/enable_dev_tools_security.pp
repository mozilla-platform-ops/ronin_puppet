# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::enable_dev_tools_security {

    if $::operatingsystem == 'Darwin' {
        exec { 'DevToolsSecurity':
            command => '/usr/sbin/DevToolsSecurity -enable',
            onlyif  => '/bin/bash -c \'[[ "$(/usr/sbin/DevToolsSecurity -status)" =~ "disabled" ]]\'',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
