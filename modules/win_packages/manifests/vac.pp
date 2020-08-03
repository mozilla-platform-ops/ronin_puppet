# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vac (
    String $creates,
    String $flags,
    String $srcloc,
    String $vac_dir,
    String $version
) {

    $driver_name = "vac${version}.exe"
    $driver_path = "${vac_dir}\\${driver_name}"

    file { $vac_dir:
        ensure => directory,
    }
    file { $driver_path :
        source => "${srcloc}/${driver_name}"
    }
    exec { $driver_name:
        command => "${facts['custom_win_system32']}\\cmd.exe /c ${driver_path} ${flags}",
        creates => $creates,
    }
}
