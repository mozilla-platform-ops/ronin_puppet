# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_update {
  # Portions of the MS tools need to be in place before updates are disabled.
  require roles_profiles::profiles::microsoft_tools

  $win_update_key    = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate"
  $win_au_key        = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\AU"

  registry_key { $win_au_key:
    ensure => present,
  }

  exec { 'disable_windows_update':
    command  => file('win_disable_services/disable_wu.ps1'),
    provider => powershell,
    timeout  => 300,
  }

  exec { 'disable_windows_update_task':
    command  => file('win_disable_services/disable_wu_task.ps1'),
    provider => powershell,
    timeout  => 300,
  }

  ## wuauserv would not stop even with a timeout.
  ## added a powershell script 
  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\wuauserv\Start':
    type => dword,
    data => '4',
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
    'win_11_2009', 'win_2022_2009': {
      service { 'UsoSvc':
        ensure => stopped,
        name   => 'UsoSvc',
        enable => false,
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
    } # Windows 11
    'win_10_2009': {
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
      registry_value { "${win_update_key}\\DeferUpgrade":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_key}\\DeferUpgradePeriod":
        type => dword,
        data => '8',
      }
      registry_value { "${win_update_key}\\DeferUpdatePeriod":
        type => dword,
        data => '4',
      }
      registry_value { "${win_au_key}\\NoAutoRebootWithLoggedOnUsers":
        type => dword,
        data => '1',
      }
      registry_value { "${win_au_key}\\ScheduledInstallDay":
        type => dword,
        data => '1',
      }
      registry_value { "${win_au_key}\\ScheduledInstallTime":
        type => dword,
        data => '1',
      }
      registry_value { "${win_au_key}\\AutomaticMaintenanceEnabled":
        type => dword,
        data => '0',
      }
      registry_value { "${win_au_key}\\MaintenanceDisabled":
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
