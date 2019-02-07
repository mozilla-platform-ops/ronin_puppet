# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define defined_classes::pkg::win_exe_pkg ($pkg, $creates=$undef, $package=$title, $install_options_string=[]) {

$pkgdir       = lookup('loc_pkg_dir')
$srcloc       = lookup('ext_pkg_src')

    file { "${pkgdir}\\${pkg}" :
        source => "${srcloc}/${pkg}",
    }
    exec { "${title}install":
        command => "${pkgdir}\\${pkg} ${install_options_string}",
        creates => $creates,
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520895

# TODO
# Add a programatic check to verify the package is installed
# Add the ability to check the version
