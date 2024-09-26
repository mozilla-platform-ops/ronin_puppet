# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::files_system_managment {
  case $facts['os']['name'] {
    'Windows': {
      include win_filesystem::disable8dot3
      include win_filesystem::disablelastaccess
      if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
        include win_filesystem::grant_cache_access
      }
      if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_d_drive'] == 'exists') {
        win_filesystem::set_paging_file { 'azure_paging_file':
          location => 'D:\pagefile.sys',
          min_size => 8192,
          max_size => 8192,
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
