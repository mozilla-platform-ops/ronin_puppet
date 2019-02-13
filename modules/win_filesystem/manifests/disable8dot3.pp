# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::disable8dot3 {

    if $::operatingsystem == 'Darwin' {
        shared::execonce { 'disable8dot3':
            command => "${facts[custom_win_system32]}\\fsutil.exe behavior set disable8dot3 1",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
