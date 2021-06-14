# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vs_buildtools {

    $prog_dir = $facts['custom_win_programfilesx86']
    $tools_dir = "${prog_dir}\\Microsoft Visual Studio\Installer"
    $vc_tools  = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
    $sdk       = 'ExtensionSDKs\Microsoft.Midi.GmDls\10.0.19041.0'
    $sdk_dir   = "${prog_dir}\\Microsoft SDKs\\Windows Kits\\10\\ExtensionSDKs\\${sdk}"

    if $::operatingsystem == 'Windows' {
        win_packages::win_exe_pkg  { 'vs_buildtools__1552942004.1623183462':
            pkg                    => 'vs_buildtools__1552942004.1623183462.exe',
            install_options_string => "--add ${vc_tools} --passive",
            creates                => "${tools_dir}\\NOTICE2.txt",
        }
        win_packages::win_exe_pkg  { 'winsdksetup':
            pkg                    => 'winsdksetup.exe',
            install_options_string => '/q /norestart',
            creates                => "${sdk_dir}\\SDKManifest",
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
