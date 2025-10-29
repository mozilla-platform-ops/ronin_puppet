# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::xvfb {
  case $facts['os']['name'] {
    'Ubuntu': {
      exec { 'apt-update-xvfb':
        command => '/usr/bin/apt-get update',
        # just use inherent ordering, see if it works
      }
      package {
        ['xauth', 'xvfb']:
          ensure => latest;
      }
    }
    default: {
      fail("Cannot install on ${facts['os']['name']}")
    }
  }
}
