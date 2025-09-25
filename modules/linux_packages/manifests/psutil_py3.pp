# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::psutil_py3 {
    require linux_packages::py3

    package { 'psutil_py3':
        ensure   => '5.9.3',
        name     => 'psutil',
        provider => pip3,
        require  => Class['linux_packages::py3'],
    }
}
