# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::intel_gfx (
  String $version
) {

    $srcloc     = lookup('windows.ext_pkg_src')
    $pkgdir     = $facts['custom_win_temp_dir']
    $gfx_driver = "gfx_win_${version}"
    $gfx_exe    = "${gfx_driver}.exe"


    file { "${pkgdir}\\${gfx_exe}" :
        source => "${srcloc}/${gfx_exe}",
    }
    exec { "${gfx_driver}_install":
        command => "${pkgdir}\\${gfx_exe} ",
        creates => "${facts['custom_win_programfiles']}\\intel\\Media",
    }
}
