# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gpu_drivers {
  case $facts['custom_win_os_version'] {
    ## Use https://docs.nvidia.com/grid/index.html & https://github.com/Azure/azhpc-extensions/blob/master/NvidiaGPU/resources.json as reference
    ['win_10_2009', 'win_11_2009']: {
      #$setup_exe   = "${facts['custom_win_systemdrive']}\\${driver_name}\\setup.exe"
      #$zip_name    = '472.39_grid_win11_win10_64bit_Azure-SWL.zip'
      #$pkgdir      = "C:\\Windows\\Temp"
      #$display_name = 'NVIDIA Graphics Driver 472.39'
      #$src_file    = "${pkgdir}\\${zip_name}"

      archive { 'NVIDIA Graphics Driver 472.39':
        ensure  => 'present',
        source  => 'https://roninpuppetassets.blob.core.windows.net/binaries/472.39_grid_win11_win10_64bit_Azure-SWL.zip',
        path    => "C:\\Windows\\Temp\\472.39_grid_win11_win10_64bit_Azure-SWL.zip",
        creates => "C:\\Windows\\Temp\\472.39_grid_win11_win10_64bit_Azure-SWL.zip",
        cleanup => false,
        extract => false,
      }

      #file { "${pkgdir}\\${zip_name}":
      #  source => "${srcloc}/${zip_name}",
      #}

      exec { 'grid_unzip':
        command  => "Expand-Archive -Path C:\\Windows\\Temp\\472.39_grid_win11_win10_64bit_Azure-SWL.zip -DestinationPath C:\\",
        creates  => "C:\\472.39_grid_win11_win10_64bit_Azure-SWL.exe",
        provider => powershell,
      }

      if $facts['custom_win_gpu'] == 'yes' {
        package { 'NVIDIA Graphics Driver 472.39' :
          ensure          => installed,
          source          => "C:\\472.39_grid_win11_win10_64bit_Azure-SWL.exe",
          install_options => ['-s','-noreboot'],
        }
      }
    }
    'win_10_2004':{
      class { 'win_packages::drivers::nvidia_grid':
        display_name => lookup('win-worker.gpu.display_name'),
        driver_name  => '391.81_grid_win10_server2016_64bit_international',
        srcloc       => lookup('windows.s3.ext_pkg_src'),
      }
    }

    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
