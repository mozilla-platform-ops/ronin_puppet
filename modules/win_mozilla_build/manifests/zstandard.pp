# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::zstandard {

    require win_mozilla_build::pip

    $needed_py3_zstandard_ver = $win_mozilla_build::needed_py3_zstandard_ver
    $mozbld = $win_mozilla_build::install_path

    if $win_mozilla_build::current_py3_zstandard_ver != $needed_py3_zstandard_ver {
        exec { 'pip_upgrade_zstandard':
            command => "${mozbld}\\python3\\python3.exe -m pip install --upgrade zstandard==${needed_py3_zstandard_ver}",
        }
    }
}
