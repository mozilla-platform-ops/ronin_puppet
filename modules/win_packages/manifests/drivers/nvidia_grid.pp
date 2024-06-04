# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::nvidia_grid (
  String $driver_name,
  String $display_name,
  String $srcloc
) {
  $setup_exe   = "${facts['custom_win_systemdrive']}\\${driver_name}\\setup.exe"
  $zip_name    = "${driver_name}.zip"
  $pkgdir      = "C:\\Windows\\Temp"
  $src_file    = "${pkgdir}\\${zip_name}"

  # copy the installtion file during image build
  # only install if it is a gpu worker with gpu in the pool name

  archive { $display_name:
    ensure  => 'present',
    source  => 'https://roninpuppetassets.blob.core.windows.net/binaries/472.39_grid_win11_win10_64bit_Azure-SWL.zip',
    path    => "C:\\472.39_grid_win11_win10_64bit_Azure-SWL.zip",
    creates => "C:\\472.39_grid_win11_win10_64bit_Azure-SWL.zip",
    cleanup => false,
    extract => false,
  }

  #file { "${pkgdir}\\${zip_name}":
  #  source => "${srcloc}/${zip_name}",
  #}

  exec { 'grid_unzip':
    command  => "Expand-Archive -Path C:\\472.39_grid_win11_win10_64bit_Azure-SWL.zip -DestinationPath C:\\",
    creates  => $setup_exe,
    provider => powershell,
  }

  if $facts['custom_win_gpu'] == 'yes' {
    package { $display_name :
      ensure          => installed,
      source          => $setup_exe,
      install_options => ['-s','-noreboot'],
    }
  }
}
