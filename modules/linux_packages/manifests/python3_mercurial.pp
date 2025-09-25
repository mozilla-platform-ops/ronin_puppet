# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::python3_mercurial {
    require linux_packages::py3

    # '6.7.4' is latest, but robustcheckout needs 6.4 or less
    package { 'python3-mercurial':
        ensure   => '6.4.5',
        name     => 'mercurial',
        provider => pip3,
    }
}
