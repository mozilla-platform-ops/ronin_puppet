# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_ultravnc::install {

    if $::operatingsystem == 'Windows' {
        win_packages::win_msi_pkg  { $win_ultravnc::package:
            pkg             => $win_ultravnc::msi,
            install_options => ['/quiet'],
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
