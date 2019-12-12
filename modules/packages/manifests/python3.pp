# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3 {

    case $::operatingsystem {
        'Darwin': {
            package { 'python3':
                ensure   => present,
                provider => brew,
            }
        }
        'Ubuntu': {
            package { 'python3':
                ensure   => present,
            }
            package { 'python3-pip':
                ensure   => present,
            }
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }


}
