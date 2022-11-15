# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::nvidia_grid (
  String $driver_name,
  String $srcloc
) {
  require win_packages::sevenzip

  $setup_exe   = "${facts['custom_win_systemdrive']}\\${driver_name}\\setup.exe"
  $working_dir = "${facts['custom_win_systemdrive']}\\${driver_name}"
  $seven_zip   = "\"${facts['custom_win_programfiles']}\\7-Zip\\7z.exe\""
  $zip_name    = "${driver_name}.zip"
  $pkgdir      = $facts['custom_win_temp_dir']
  $src_file    = "\"${pkgdir}\\${zip_name}\""

  # copy the installtion file during image build
  # only install if it is a gpu worker with gpu in the pool name

  file { $working_dir:
    ensure => directory,
  }
  file { "${pkgdir}\\${zip_name}":
    source => "${srcloc}/${zip_name}",
  }
  if $facts['custom_win_gpu'] == 'yes' {
    exec { 'grid_unzip':
      command  => "Expand-Archive -Path ${src_file} -DestinationPath ${working_dir}",
      creates  => $setup_exe,
      provider => powershell,
    }
    exec { 'grid_install':
      command     => "${facts['custom_win_system32']}\\cmd.exe /c ${setup_exe} -s -noreboot",
      subscribe   => Exec['grid_unzip'],
      refreshonly => true,
    }
  }
}
