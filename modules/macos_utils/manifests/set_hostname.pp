# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::set_hostname {

    if $::operatingsystem == 'Darwin' {
        exec { 'SetLocalHostName':
            command => '/usr/sbin/scutil --set LocalHostName $(hostname|cut -d\. -f2)',
            onlyif  => 'test $(/usr/sbin/scutil --get LocalHostName) != "$(hostname|cut -d\. -f2)"',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
