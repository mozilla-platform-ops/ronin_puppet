# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vc_redist_x86 {

    if $::operatingsystem == 'Windows' {
        win_packages::win_exe_pkg  { 'vc_redist_x86':
            pkg                    => 'vc_redist_x86.exe',
            install_options_string =>
                "/install /passive  /norestart /log  ${facts['custom_win_roninlogdir']}\\vcredist_vs2015_x86-install.log",
            creates                => "${facts['custom_win_systemdrive']}\\Windows\\System32\\vcruntime140.dll",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
