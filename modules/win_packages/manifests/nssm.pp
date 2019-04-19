# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::nssm {

    if $::operatingsystem == 'Windows' {

        $version = '2.24-103-gdee49fc'

        win_packages::win_zip_pkg { "nssm-${version}":
            pkg         => "nssm-${version}.zip",
            creates     => "${facts['custom_win_systemdrive']}\\nssm\\nssm-${version}\\win64\\nssm.exe",
            destination => "${facts['custom_win_systemdrive']}\\nssm\\",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
