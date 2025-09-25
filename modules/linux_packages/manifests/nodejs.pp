# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::nodejs {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04':  {
          package {
            'nodejs':
              ensure => latest;
            'nodejs-legacy':
              ensure => absent,
              before => Package['nodejs'];
          }
        }
        default: {
          fail("Ubuntu ${::operatingsystemrelease} is not supported")
        }
      }
    }
    default: {
      fail("Cannot install on ${::operatingsystem}")
    }
  }
}
