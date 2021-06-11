# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vs_buildtools {

    $sdk_dir = "${facts['custom_win_programfilesx86']}\\Microsoft SDKs"

    if $::operatingsystem == 'Windows' {
        win_packages::win_exe_pkg  { 'vs_buildtools__1552942004.1623183462':
            pkg                    => 'visualcppbuildtools_full.exe',
            install_options_string => '--quiet',
            creates                =>
                "${sdk_dir}\\Windows Kits\\10\\ExtensionSDKs\\Microsoft.UniversalCRT.Debug\\10.0.10240.0\\343.xml",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
