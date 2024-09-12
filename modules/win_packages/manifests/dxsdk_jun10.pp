# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::dxsdk_jun10 {

    $prog86x = $facts['custom_win_programfilesx86']
    $sdk_dir = 'Microsoft DirectX SDK (June 2010)'
    $file    = 'DXSDK_Jun10.exe'

    case $facts['az_metadata']['compute']['publisher'] {
        'microsoftwindowsdesktop': {
            exec { 'install_net_framework3.5':
                command  => 'Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All',
                provider => powershell,
                timeout  => 600,
            }
        }
        default: {
            windowsfeature { 'NET-Framework-Core':
                ensure => present,
            }
        }
    }

    win_packages::win_exe_pkg  { 'dxsdk_jun10':
        pkg                    => 'DXSDK_Jun10.exe',
        install_options_string => '/U',
        creates                => "${prog86x}\\${sdk_dir}\\Include\\audiodefs.h",
        returns                => [0, 1023],
    }
    windows::environment { 'DXSDK_DIR':
        value => "${facts['custom_win_programfilesx86']}\\${sdk_dir}"
    }
}
