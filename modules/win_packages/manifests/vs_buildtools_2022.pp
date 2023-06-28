# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vs_buildtools_2022 {

    $prog_dir = $facts['custom_win_programfilesx86']
    $tools_dir = "${prog_dir}\\Microsoft Visual Studio\\Installer"

    if $facts['os']['name'] == 'Windows' {
        win_packages::win_exe_pkg  { 'vs_buildtools_2022':
            pkg                    => 'vs_buildtools_2022.exe',
            install_options_string => '--all --passive --norestart',
            creates                => "${tools_dir}\\NOTICE.txt",
        }
    } else {
        fail("${module_name} does not support ${$facts['os']['name']}")
    }
}
