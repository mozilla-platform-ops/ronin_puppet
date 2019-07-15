# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::nircmd {

    $system32 = $facts['custom_win_system32']
    $srcloc   = lookup('win_ext_pkg_src')

    file { "${system32}\\nircmd.exe":
        ensure => present,
        source => "${srcloc}/nircmd.exe",
    }
    file { "${system32}\\nircmdc.exe":
        ensure => present,
        source => "${srcloc}/nircmdc.exe",
    }
}
