# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::sox {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04': {
          package {
            ['libsox-fmt-alsa', 'libsox-fmt-base', 'libsox3', 'sox']:
              ensure => 'latest';
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
