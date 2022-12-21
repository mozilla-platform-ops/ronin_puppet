# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::cppbuildtools {

    # reduce path length so it may pass linting
    $sdk_dir = "${facts['custom_win_programfilesx86']}\\Microsoft SDKs"

    if $::operatingsystem == 'Windows' {
        win_packages::win_exe_pkg  { 'visualcppbuildtools_full2015':
            pkg                    => 'visualcppbuildtools_full.exe',
            install_options_string => '/q',
            creates                =>
                "${sdk_dir}\\Windows Kits\\10\\ExtensionSDKs\\Microsoft.UniversalCRT.Debug\\10.0.10240.0\\SDKManifest.xml",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
