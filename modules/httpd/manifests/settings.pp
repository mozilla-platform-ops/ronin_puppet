# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class httpd::settings {

    case $::operatingsystem {
        'Darwin': {
            $group      = 'wheel'
            $owner      = 'root'
            $mode       = '0644'
            $conf_d_dir = '/etc/apache2/other'
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
