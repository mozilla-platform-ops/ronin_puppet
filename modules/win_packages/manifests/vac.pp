# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vac (
    String $flags,
    String $version
) {

    $driver_name = 'vac{version}'

    win_packages::win_exe_pkg { $driver_name:
        pkg                    => "${driver_name}.zip",
        install_options_string => $flags,
        creates                => 'C:\VBCABLE_setup.exe',
    }
}
