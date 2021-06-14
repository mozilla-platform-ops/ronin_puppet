# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vs_buildtools {

    $tools_dir = "${facts['custom_win_systemdrive']}\\vs_tools"

    if $::operatingsystem == 'Windows' {
        win_packages::win_exe_pkg  { 'vs_buildtools__1552942004.1623183462':
            pkg                    => 'vs_buildtools__1552942004.1623183462.exe',
            install_options_string => '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --passive',
            creates                => "${tools_dir}\\LaunchDevCmd.bat",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
