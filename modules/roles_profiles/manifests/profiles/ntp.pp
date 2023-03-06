# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ntp {
  case $facts['os']['name'] {
    'Darwin': {
      class { 'macos_ntp':
        enabled    => true,
        ntp_server => lookup('ntp_server'),
      }
    }
    'Ubuntu': {
      $ntp_server = lookup('ntp_server', String)
      class { 'ntp':
        servers => [$ntp_server],
      }
    }
    'Windows': {
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1510754
      # For windowstime resoucre timezone and server needs to be set in the same class
      # Resource from ncorrare-windowstime
      case $facts['custom_win_location'] {
        'datacenter': {
          $ntpserver = lookup('windows.datacenter.ntp')
          class { 'windowstime':
            servers  => { "${ntpserver}" => '0x08' },
            timezone => 'Greenwich Standard Time',
          }
        }
        default: {
          exec { 'timezone':
            command  => "Set-TimeZone -Name 'Coordinated Universal Time'",
            provider => powershell,
          }
        }
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
