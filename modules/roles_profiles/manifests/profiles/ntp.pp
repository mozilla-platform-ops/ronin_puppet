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
      case $facts['os']['release']['full'] {
        /^18\.04/,
        /^19\./,
        /^20\./,
        /^21\./,
        /^22\.04/: {
          package { 'ntp':
            ensure => latest,
          }
        }
        /^24\.04/: {
          # uses timedatectl and timesyncd
          require 'linux_ntp'
        }
        default: {
          fail("Unsupported Ubuntu version for NTP: ${facts['os']['release']['full']}")
        }
      }
    }
    'Windows': {
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1510754
      # For windowstime resoucre timezone and server needs to be set in the same class
      # Resource from ncorrare-windowstime
      if $facts['custom_win_location'] == 'datacenter' {
        $ntpserver = lookup('windows.datacenter.ntp')
      } else {
        $ntpserver = lookup('windows.external.ntp')
      }
      class { 'windowstime':
        servers  => { "${ntpserver}" => '0x08' },
        timezone => 'Greenwich Standard Time',
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
