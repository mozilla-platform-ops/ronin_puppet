# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::virtualenv (
    String $version = '16.4.3',
) {
    require packages::python3

    package { 'virtualenv':
        ensure   => $version,
        provider => pip3,
        require  => Class['packages::python3'],
    }
}
