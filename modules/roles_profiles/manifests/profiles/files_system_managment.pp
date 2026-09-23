# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::files_system_managment {
  case $facts['os']['name'] {
    'Windows': {
      $task_drive = lookup('windows_task_drive', { 'default_value' => undef })
      if $task_drive {
        $cache_drive = $task_drive
      } elsif $facts['custom_win_d_drive'] == 'exists' {
        $cache_drive = 'D:'
      } else {
        $cache_drive = 'C:'
      }
      $startup_task_drive = $task_drive ? { undef => 'D:', default => $task_drive }
      registry_value { 'HKLM\SOFTWARE\Mozilla\ronin_puppet\task_drive':
        type => string,
        data => $startup_task_drive,
      }
      include win_filesystem::disable8dot3
      include win_filesystem::disablelastaccess
      if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
        class { 'win_filesystem::grant_cache_access':
          cache_drive => $cache_drive,
        }
      }
      if ($facts['custom_win_location'] == 'azure') and ($task_drive or ($facts['custom_win_d_drive'] == 'exists')) {
        win_filesystem::set_paging_file { 'azure_paging_file':
          location => "${cache_drive}\\pagefile.sys",
          min_size => 8192,
          max_size => 8192,
        }
      }
      include win_os_settings::enable_long_paths
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
