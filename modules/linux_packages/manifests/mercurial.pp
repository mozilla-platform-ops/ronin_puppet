# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::mercurial {
  case $::operatingsystem {
    'Ubuntu': {
      include linux_packages::python2_mercurial
      include linux_packages::python3_mercurial

      package {
          'mercurial':
              ensure => present;
      }
    }
    default: {
      fail("Cannot install on ${::operatingsystem}")
    }
  }
}
