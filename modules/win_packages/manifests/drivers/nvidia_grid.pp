# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::nvidia_grid (
    String $driver_name,
) {

    $setup_exe   = "${facts['custom_win_systemdrive']}\\${driver_name}\\setup.exe"
    $working_dir = "${facts['custom_win_systemdrive']}\\${driver_name}"

    win_packages::win_zip_pkg { $driver_name:
        pkg         => "${driver_name}.zip",
        creates     => $setup_exe,
        destination => $working_dir,
    }
    exec { "${driver_name}_install":
        command     => "${setup_exe} -s -noreboot",
        subscribe   => File[$working_dir],
        refreshonly => true,
        provider    => powershell,
    }
}
