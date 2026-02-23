# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::custom_nssm (
    String $version,
    String $nssm_dir,
    String $nssm_exe
) {

    win_packages::win_zip_pkg { "nssm-${version}":
        pkg         => "nssm-${version}.zip",
        creates     => $nssm_exe,
        destination => $nssm_dir,
    }
}
