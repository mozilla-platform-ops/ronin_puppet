# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_msi_pkg ( $pkg, $package=$title, $install_options=[]) {

$pkgdir = $facts['custom_win_temp_dir']
$srcloc = lookup('win_ext_pkg_src')

    file { "${pkgdir}\\${pkg}" :
        source => "${srcloc}/${pkg}",
    }
    package { $title :
        ensure  => installed,
        source  => "${pkgdir}\\${pkg}",
        require => File["${pkgdir}\\${pkg}"],
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1519928
