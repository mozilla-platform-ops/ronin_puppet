# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::psutil_py2 {
    require linux_packages::py2

    package { 'psutil_py2':
        ensure   => '5.7.0',
        name     => 'psutil',
        provider => pip,
        require  => Class['linux_packages::py2'],
    }
}
