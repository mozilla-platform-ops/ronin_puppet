# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::python2_mercurial {
    require linux_packages::py2

    # robustcheckout is super slow with 4.9+
    # see https://bugzilla.mozilla.org/show_bug.cgi?id=1672816
    package { 'python2-mercurial':
        ensure   => '4.8.1',
        name     => 'mercurial',
        provider => pip,
    }
}
