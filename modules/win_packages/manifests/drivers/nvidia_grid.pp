# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::nvidia_grid (
  String $driver_name,
  String $display_name,
  String $srcloc
) {
  $driver_exe   = "${facts['custom_win_temp_dir']}\\${driver_name}.exe"

  if $facts['custom_win_gpu'] == 'yes' {
    file { $driver_exe:
      source => "${srcloc}/${driver_name}.exe",
    }
    package { $display_name :
      ensure          => 'present',
      source          => $driver_exe,
      install_options => ['-s','-noreboot'],
    }
  }
}
