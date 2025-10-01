# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#

class win_disable_services::disable_windows_defender_schtask {
  $script_dir = "${facts['custom_win_roninprogramdata']}\\disable_win_defend"
  $main_bat = "${script_dir}\\DisableWindowsDefender.bat"

  file { $script_dir:
    ensure => directory,
  }
  file { "${script_dir}\\OwnRegistryKeys.bat":
    ensure  => file,
    content => file('win_disable_services/windows_defender/OwnRegistryKeys.bat'),
  }
  file { "${script_dir}\\OwnRegistryKeys.ps1":
    ensure  => file,
    content => file('win_disable_services/windows_defender/OwnRegistryKeys.ps1'),
  }
  file { $main_bat:
    ensure  => file,
    content => file('win_disable_services/windows_defender/DisableWindowsDefender.bat'),
  }
  file { "${script_dir}\\DisableWindowsDefenderfeatures.reg":
    ensure  => file,
    content => file('win_disable_services/windows_defender/DisableWindowsDefenderfeatures.reg'),
  }
  file { "${script_dir}\\DisableWindowsDefenderobjects.reg":
    ensure  => file,
    content => file('win_disable_services/windows_defender/DisableWindowsDefenderobjects.reg'),
  }
  file { "${script_dir}\\DisableWindowsDefenderservices.reg":
    ensure  => file,
    content => file('win_disable_services/windows_defender/DisableWindowsDefenderservices.reg'),
  }
  scheduled_task { 'disable_windows_defender':
    ensure      => 'present',
    command     => $main_bat,
    working_dir => $script_dir,
    enabled     => true,
    trigger     => [{
        'schedule'         => 'boot',
        'minutes_interval' => '0',
        'minutes_duration' => '0'
    }],
    user        => 'system',
  }
  exec { 'disable_windows_defender_1st_run':
    command     => "${facts['custom_win_system32']}\\cmd.exe /c ${$main_bat}",
    cwd         => $script_dir,
    refreshonly => true,
    subscribe   => File[$main_bat],
  }
}
