# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_update {
  # Portions of the MS tools need to be in place before updates are disabled.
  require roles_profiles::profiles::microsoft_tools

  $win_update_key    = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate"
  $win_au_key        = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"

  registry_key { $win_au_key:
    ensure => present,
  }

  case $facts['custom_win_os_version'] {
    'win_2012': {
      # Using puppetlabs-registry
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching\SearchOrderConfig':
        type => dword,
        data => '0',
      }
      registry_value { "${win_au_key}\\AUOptions":
        type => dword,
        data => '1',
      }
      registry_value { "${win_au_key}\\NoAutoUpdate":
        type => dword,
        data => '1',
      }
    }
    'win_11_2009', 'win_2022_2009', 'win_10_2009': {
      ## wuauserv would not stop even with a timeout.
      ## added a powershell script + additional reg paths
      registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\wuauserv\Start':
        type => dword,
        data => '4',
      }
      ## Scheduled task to kill windows update/windows update-related scheduled tasks
      $disable_wu_task_ps = "${facts['custom_win_roninprogramdata']}\\disable_wu_task.ps1"

      file { $disable_wu_task_ps:
        content => file('win_disable_services/disable_wu_task.ps1'),
      }
      # Resource from puppetlabs-scheduled_task
      scheduled_task { 'disable_wu':
        ensure    => 'present',
        command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
        arguments => "-executionpolicy bypass -File ${disable_wu_task_ps}",
        enabled   => true,
        trigger   => [{
            'schedule'         => 'boot',
            'minutes_interval' => '0',
            'minutes_duration' => '0'
        }],
        user      => 'system',
      }

      registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc\Start':
        type => dword,
        data => '4',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching\SearchOrderConfig':
        type => dword,
        data => '0',
      }
      registry_value { "${win_au_key}\\AUOptions":
        type => dword,
        data => '1',
      }
      registry_value { "${win_au_key}\\NoAutoUpdate":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_key}\\DoNotConnectToWindowsUpdateInternetLocations":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_key}\\DisableWindowsUpdateAccess":
        type => dword,
        data => '1',
      }
    }
    default: {
      fail("${module_name} does not support ${$facts['custom_win_os_version']}")
    }
  }
}

# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=>1510756
# https://bugzilla.mozilla.org/show_bug.cgi?id=>1485628
