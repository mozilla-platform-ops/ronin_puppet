# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::files_system_managment {
  case $facts['os']['name'] {
    'Windows': {
      $win_worker_function = lookup('win-worker.function', { 'default_value' => undef })
      $configure_azure_temp_drive = ($facts['custom_win_location'] == 'azure') and ($win_worker_function in ['builder', 'tester'])
      if $facts['custom_win_d_drive'] == 'exists' {
        $cache_drive = 'D:'
      } else {
        $cache_drive = 'C:'
      }
      if $configure_azure_temp_drive {
        include win_filesystem::configure_nvme_disk
        $azure_temp_drive_require = Class['win_filesystem::configure_nvme_disk']
      } else {
        $azure_temp_drive_require = undef
      }
      include win_filesystem::disable8dot3
      include win_filesystem::disablelastaccess
      if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
        class { 'win_filesystem::grant_cache_access':
          cache_drive => $cache_drive,
          require     => $azure_temp_drive_require,
        }
      }
      if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_d_drive'] == 'exists') {
        win_filesystem::set_paging_file { 'azure_paging_file':
          location => 'D:\pagefile.sys',
          min_size => 8192,
          max_size => 8192,
          require  => $azure_temp_drive_require,
        }
      }
      ## If tester then enable long path
      ## Limit long paths on hardware to rule out problem with tests failing
      if ($facts['custom_win_purpose'] == 'tester') {
        include win_os_settings::enable_long_paths
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
