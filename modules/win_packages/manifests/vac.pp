# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vac (
    String $flags,
    String $srcloc,
    String $vac_dir,
    String $version,
    String $work_dir
) {

    $zip_name    = "vac${version}.zip"
    $exe_name    = "${work_dir}\\setup64.exe"
    $pkgdir      = $facts['custom_win_temp_dir']
    $seven_zip   = "\"${facts['custom_win_programfiles']}\\7-Zip\\7z.exe\""
    $src_file    = "\"${pkgdir}\\${zip_name}\""


    file { $vac_dir:
        ensure => directory,
    }
    file {  "${pkgdir}\\${zip_name}":
        source => "${srcloc}/${zip_name}"
    }
    exec { 'vac_unzip':
        command => "${seven_zip} x ${src_file} -o${vac_dir} -y",
        creates => $exe_name,
    }
    exec { 'vac_install':
        command     => "${facts['custom_win_system32']}\\cmd.exe /c ${exe_name} ${flags}",
        subscribe   => Exec['vac_unzip'],
        refreshonly => true,
    }
}
