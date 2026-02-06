# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nsclient::init (
  String $server,
  String $server_pw,
){
  $nscp_dir    = "${facts['custom_win_programfiles']}\\NSClient++"
  $scripts_dir = "${nscp_dir}\\scripts"

  win_packages::win_msi_pkg { 'NSClient++ (x64)':
    pkg             => 'NSCP-0.9.15-x64.msi',
    install_options => ['/quiet'],
  }

  # Barrier: don't try to drop files until the dir exists
  file { $nscp_dir:
    ensure  => directory,
    require => Win_packages::Win_msi_pkg['NSClient++ (x64)'],
  }

  file { $scripts_dir:
    ensure  => directory,
    require => File[$nscp_dir],
  }

  file { "${nscp_dir}\\nsclient.ini":
    content   => epp('win_nsclient/nsclient.ini.epp', {
      'server'    => $server,
      'server_pw' => $server_pw,
    }),
    show_diff => false,
    require   => File[$nscp_dir],
    notify    => Service['nscp'],
  }

  file { "${scripts_dir}\\screen_res.ps1":
    content => file('win_nsclient/screen_res.ps1'),
    require => File[$scripts_dir],
    notify  => Service['nscp'],
  }

  service { 'nscp':
    ensure  => running,
    enable  => true,
    require => Win_packages::Win_msi_pkg['NSClient++ (x64)'],
  }
  win_firewall::open_local_port { 'nscp_12489':
    port            => 12489,
    reciprocal      => true,
    fw_display_name => 'nscp_12489',
  }
  win_firewall::open_local_port { 'nscp_5666':
    port            => 12489,
    reciprocal      => true,
    fw_display_name => 'nscp_5666',
  }
}
