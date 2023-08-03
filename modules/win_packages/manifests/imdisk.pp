# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::imdisk (
    String $srcloc
) {
    $zip_name    = 'ImDiskTk-x64.zip'
    $install_dir = "${$facts['custom_win_programfiles']}\\ImDisk"
    $creates     = "${install_dir}\\config.exe"
    $pkgdir      = $facts['custom_win_temp_dir']
    $loc_zip     = "${pkgdir}\\${zip_name}"
    $imdisk_dir  = "${facts['custom_win_systemdrive']}\\ImDiskTk20220826"
    $bat         = "${imdisk_dir}\\install.bat"

    file { $imdisk_dir:
        ensure => directory,
    }
    file { $loc_zip:
        source => "${srcloc}/${zip_name}",
    }
    exec { 'imdisk_unzip':
        command  => "Expand-Archive -Path ${loc_zip} -DestinationPath ${facts['custom_win_systemdrive']}\\",
        creates  => $bat,
        provider => powershell,
    }
    exec { 'imdisk_install':
        command  => "${bat} /fullsilent",
        creates  => $creates,
        provider => powershell,
    }
}
