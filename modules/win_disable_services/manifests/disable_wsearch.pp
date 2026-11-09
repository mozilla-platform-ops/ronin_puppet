# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## Keep Windows Search indexing off on non-builder workers.
## Azure workers must disable startup before stopping to avoid a service restart race.

class win_disable_services::disable_wsearch {
  if $facts['os']['name'] == 'Windows' {
    case $facts['custom_win_location'] {
      'datacenter': {
        exec { 'disable_wsearch':
          command  => file('win_disable_services/wsearch/disable.ps1'),
          provider => powershell,
          timeout  => 300,
        }
      }
      'azure': {
        ## Disable first so a restart cannot race the stop; retry if it does.
        exec { 'disable_wsearch':
          command   => '$ErrorActionPreference = "Stop"; Set-Service wsearch -StartupType Disabled; Stop-Service wsearch -Force',
          provider  => powershell,
          timeout   => 300,
          tries     => 5,
          try_sleep => 5,
          unless    => '$s = Get-Service wsearch -ErrorAction SilentlyContinue; if (-not $s) { exit 0 }; if ($s.Status -ne "Stopped" -or $s.StartType -ne "Disabled") { exit 1 }',
        }
      }
      default: {
        win_disable_services::disable_service { 'wsearch':
        }
      }
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
