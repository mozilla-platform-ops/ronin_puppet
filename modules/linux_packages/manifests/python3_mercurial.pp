# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::python3_mercurial {
    require linux_packages::py3

    package { 'python3-mercurial':
        ensure   => '4.7.1',
        name     => 'mercurial',
        provider => pip3,
    }
}
