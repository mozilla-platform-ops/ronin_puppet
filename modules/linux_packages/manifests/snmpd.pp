# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::snmpd {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          package {
            'snmpd':
              ensure => present;
          }
        }
        default: {
          fail("Ubuntu ${facts['os']['release']['full']} is not supported")
        }
      }
    }
    default: {
      fail("${facts['os']['name']} is not supported")
    }
  }
}
