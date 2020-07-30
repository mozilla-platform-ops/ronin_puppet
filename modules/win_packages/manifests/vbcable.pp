# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vbcable (
    String $directory,
    String $version
) {

    $driver_name = "vbcable_driver_pack${version}"

    win_packages::win_zip_pkg { $driver_name:
            pkg         => "${driver_name}.zip",
            creates     => $directory,
            destination => $directory,
    }

    # Using puppetlabs-powershell
    exec { "install_${$driver_name}":
        command     => "${directory}\\VBCABLE_Setup_x64.exe -i -h",
        subscribe   => Exec["${driver_name}.zip"],
        refreshonly => true,
    }
}
