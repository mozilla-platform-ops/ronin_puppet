# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#

class win_disable_services::disable_windows_defender_schtask {
  require win_shared::win_ronin_dirs

  $script_dir = "${facts['custom_win_roninprogramdata']}\\disable_win_defend"
  $main_script = "${script_dir}\\DisableWindowsDefender.ps1"
  $powershell = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe"
  $arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${main_script}\""
  $script_names = [
    'DisableWindowsDefender.ps1',
    'OwnRegistryKeys.ps1',
    'DisableWindowsDefenderfeatures.reg',
    'DisableWindowsDefenderobjects.reg',
    'DisableWindowsDefenderservices.reg',
  ]
  $script_files = $script_names.map |$name| { "${script_dir}\\${name}" }

  file { $script_dir:
    ensure => directory,
  }
  acl { $script_dir:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => File[$script_dir],
  }
  $script_names.each |$name| {
    file { "${script_dir}\\${name}":
      ensure  => file,
      content => file("win_disable_services/windows_defender/${name}"),
      require => Acl[$script_dir],
    }
  }
  scheduled_task { 'disable_windows_defender':
    ensure      => 'present',
    command     => $powershell,
    arguments   => $arguments,
    working_dir => $facts['custom_win_system32'],
    enabled     => true,
    trigger     => [{
        'schedule'         => 'boot',
        'minutes_interval' => '0',
        'minutes_duration' => '0'
    }],
    user        => 'system',
    require     => File[$script_files],
  }
  exec { 'disable_windows_defender_1st_run':
    command     => "\"${powershell}\" ${arguments}",
    cwd         => $facts['custom_win_system32'],
    refreshonly => true,
    subscribe   => File[$script_files],
    require     => Scheduled_task['disable_windows_defender'],
  }
}
