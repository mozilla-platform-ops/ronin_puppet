# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_update {
  $win_update_key    = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate"
  $win_update_au_key = "${win_update_key}\\AU"
  $win_au_key        = "HKLM\\SOFTWARE\\Microsoft\\Windows\\Windows\\AU"
  service { 'wuauserv':
    ensure => stopped,
    name   => 'wuauserv',
    enable => false,
  }
  case $facts['custom_win_release_id'] {
    '2009': {
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
    } # Windows 11
    '2004': {
      # Using puppetlabs-registry
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching\SearchOrderConfig':
        type => dword,
        data => '0',
      }
      registry_key { $win_au_key:
        ensure => present,
      }
      registry_value { "${win_au_key}\\AUOptions":
        type => dword,
        data => '1',
      }
      registry_value { "${win_au_key}\\NoAutoUpdate":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_au_key}\\NoAutoUpdate":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_au_key}\\AUOptions":
        type => dword,
        data => '2',
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
      registry_value { "${win_update_au_key}\\NoAutoRebootWithLoggedOnUsers":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_au_key}\\ScheduledInstallDay":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_au_key}\\ScheduledInstallTime":
        type => dword,
        data => '1',
      }
      registry_value { "${win_update_au_key}\\AutomaticMaintenanceEnabled":
        type => dword,
        data => '0',
      }
      registry_value { "${win_update_au_key}\\MaintenanceDisabled":
      } # Windows 10 20h2
    }
    default: {
      fail("${module_name} does not support ${$facts['os']['kernelrelease']}")
    }
  }
}

# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=>1510756
# https://bugzilla.mozilla.org/show_bug.cgi?id=>1485628
