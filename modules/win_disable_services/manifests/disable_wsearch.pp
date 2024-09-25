# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## If we are on azure, we may need to disable wsearch
## Disable for now but leave the code in the bottom of this configuration
## This may be causing bc1 for win/debug-msix to fail

class win_disable_services::disable_wsearch {
  if $facts['os']['name'] == 'Windows' {
    exec { 'disable_wsearch':
      command  => file('win_disable_services/wsearch/disable.ps1'),
      provider => powershell,
      timeout  => 300,
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}

# case $facts['custom_win_location'] {
#   'datacenter': {
#     exec { 'disable_wsearch':
#       command  => file('win_disable_services/wsearch/disable.ps1'),
#       provider => powershell,
#       timeout  => 300,
#     }
#   }
#   'azure':{ ## Let's use this method of disabling service on cloud workers
#     win_disable_services::disable_service { 'wsearch':
#     }
#   }
#   default: {
#     $source_location = lookup('windows.ext_pkg_src')
#   }
# }
