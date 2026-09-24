# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::nvidia_grid (
  String $driver_name,
  String $display_name,
  String $srcloc
) {
  include win_packages::staging
  $pkg          = "${driver_name}.exe"
  $driver_exe   = "${win_packages::staging::path}\\${pkg}"

  archive { $driver_name:
    ensure  => 'present',
    source  => "${srcloc}/${driver_name}.exe",
    path    => $driver_exe,
    creates => $driver_exe,
    cleanup => false,
    extract => false,
    require => Class['win_packages::staging'],
  }

  acl { $driver_exe:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => Archive[$driver_name],
  }

  if $facts['custom_win_gpu'] == 'yes' {
    package { $display_name :
      ensure          => 'present',
      source          => $driver_exe,
      install_options => ['-s','-noreboot'],
      require         => Acl[$driver_exe],
    }
  }
}
