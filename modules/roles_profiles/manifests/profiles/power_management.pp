# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::power_management {
  case $facts['os']['name'] {
    'Darwin': {
      include macos_mobileconfig_profiles::power_management
    }
    'Windows': {
      case $facts['custom_win_location'] {
        'datacenter': {
          ## no sleep  on hardware to rule out problem with tests failing
          include win_os_settings::no_sleep
          $guid = 'e9a42b02-d5df-448d-aa00-03f14749eb61' # Ultimate Performance
        }
        default: {
          $guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' # High Performance
        }
      }

      # Use POWERCFG.EXE to set the desired power scheme.
      exec { 'windows-powercfg':
        command  => "POWERCFG -SETACTIVE ${guid}",
        unless   => template('windows/powercfg_check.ps1.erb'),
        provider => 'powershell',
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
