# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# ia32-libs are needed by b2g emulator tests
class linux_packages::ia32libs {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04': {
          # from Alin Selagea, 2017-03-14:
          # In ubuntu 16.04, ia32-libs was replaced with lib32z1 lib32ncurses5
          # When I tried to install ia32-libs, I received the error:
          # However the following packages replace it:
          # lib32z1 lib32ncurses5
          case $::hardwaremodel {
            'x86_64': {
              package {
                'lib32ncurses5':
                  ensure => 'latest';
              }
            }
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
