# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class httpd {

    case $facts['os']['name'] {
        'Darwin': {
            service { 'httpd':
                ensure => running,
                name   => 'org.apache.httpd',
                enable => true,
            }
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
