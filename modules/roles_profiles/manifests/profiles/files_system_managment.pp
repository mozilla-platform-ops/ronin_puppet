# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::files_system_managment {
  case $facts['os']['name'] {
    'Windows': {
      include win_filesystem::disable8dot3
      include win_filesystem::disablelastaccess
      if $facts['custom_win_location'] == 'azure' {
        if $facts['custom_win_y_drive'] == 'exists' {
          win_filesystem::set_paging_file { 'azure_paging_file':
            location => 'y:\pagefile.sys',
            min_size => 8192,
            max_size => 8192,
          }
        }
        if $facts['custom_win_z_drive'] == 'exists' {
          include win_filesystem::grant_z_access
        }
      }
      case $facts['custom_win_os_version'] {
        'win_10_2009':{
          include win_os_settings::enable_long_paths
        }
        'win_11_2009':{
          include win_os_settings::enable_long_paths
        }
        default: {
          fail("${$facts['os']['name']} not supported")
        }
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
