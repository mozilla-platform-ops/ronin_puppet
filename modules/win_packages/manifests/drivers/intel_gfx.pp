# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::intel_gfx (
  String $version
) {

    case $facts['custom_win_location'] {
        'datacenter': {
            $srcloc       = lookup('windows.s3.ext_pkg_src')
        }
        default: {
            $srcloc = lookup('windows.ext_pkg_src')
        }
    }

    $pkgdir     = $facts['custom_win_temp_dir']
    $gfx_driver = "gfx_win_${version}"
    $gfx_exe    = "${gfx_driver}.exe"


    file { "${pkgdir}\\gfx.exe" :
        source => "${srcloc}/${gfx_exe}",
    }
    if ($facts['custom_display_adpater'] != 'Intel(R)Iris(R)XeGraphics') {
        exec { "${gfx_driver}_install":
            command  => 'C:\Windows\Temp\gfx.exe -s -f --noExtras',
            #command  => file('win_packages/gfx.ps1'),
            provider => powershell,
        }
    }
}
