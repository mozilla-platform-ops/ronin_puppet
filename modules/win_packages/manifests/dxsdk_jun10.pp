# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::dxsdk_jun10 {
  if $facts['custom_win_os_arch'] != 'aarch64' and $facts['custom_win_os_version'] != 'win_2025_2009' {
    $prog86x = $facts['custom_win_programfilesx86']
    $sdk_dir = 'Microsoft DirectX SDK (June 2010)'
    $file    = 'DXSDK_Jun10.exe'

    case $facts['az_metadata']['compute']['publisher'] {
      'microsoftwindowsdesktop': {
        exec { 'install_net_framework3.5':
          command   => 'Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All',
          provider  => powershell,
          tries     => 3,
          try_sleep => 10,
          timeout   => 1200,
        }
      }
      default: {
        # Install NetFx3 from the build 20348 Features on Demand cab. Windows Update
        # cannot serve it for Catalog-only builds such as 20348.5773 (KB5134140).
        include win_packages::staging
        $netfx3_dir = "${win_packages::staging::path}\\netfx3"
        $netfx3_cab = 'Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~~.cab'

        file { $netfx3_dir:
          ensure  => directory,
          require => Class['win_packages::staging'],
        }
        archive { 'netfx3_cab':
          ensure          => present,
          source          => "${lookup('windows.ext_pkg_src')}/${netfx3_cab}",
          path            => "${netfx3_dir}\\${netfx3_cab}",
          creates         => "${netfx3_dir}\\${netfx3_cab}",
          cleanup         => false,
          extract         => false,
          checksum        => '53470dc8bec1f5343109732aaeb7655dc1988f5ed6967dd129acdf9693e293bb',
          checksum_type   => 'sha256',
          checksum_verify => true,
          require         => File[$netfx3_dir],
        }
        exec { 'install_net_framework3.5':
          command  => "dism.exe /online /enable-feature /featurename:NetFx3 /all /source:${netfx3_dir} /limitaccess /norestart /quiet",
          unless   => 'if ((Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -ne "Enabled") { exit 1 }',
          provider => powershell,
          returns  => [0, 3010],
          timeout  => 1200,
          require  => Archive['netfx3_cab'],
        }
      }
    }

    win_packages::win_exe_pkg { 'dxsdk_jun10':
      pkg                    => $file,
      install_options_string => '/U',
      creates                => "${prog86x}\\${sdk_dir}\\Include\\audiodefs.h",
      returns                => [0, 1023],
    }
    windows::environment { 'DXSDK_DIR':
      value => "${facts['custom_win_programfilesx86']}\\${sdk_dir}",
    }
  }
}
