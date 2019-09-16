# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python2_zstandard {
    require packages::python2

    package { 'python2-zstandard':
        ensure   => '0.11.1',
        name     => 'zstandard',
        provider => pip,
        require  => Class['packages::python2'],
    }
}
