# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_zip_pkg ( $pkg, $destination, $package=$title, $creates=[] ) {

$pkgdir = lookup('loc_pkg_dir')
$srcloc = lookup('ext_pkg_src')

    file { "${pkgdir}\\${pkg}":
        source => "${srcloc}/${pkg}",
    }
    file { $destination:
        ensure => directory,
    }
    unzip { $pkg :
        destination => $destination,
        creates     => $creates,
        source      => "${pkgdir}\\${pkg}",
        require     => File["${pkgdir}\\${pkg}"],
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520038
