# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# python3-launchpad is part of a base ubuntu system, but
# it defines python3-testresources as optional, but the
# python code requires it.
#
# see https://bugs.launchpad.net/launchpadlib/+bug/1019700

class linux_packages::testresources {
  case $::operatingsystem {
    'Ubuntu': {
      package {
        'python-testresources':
          ensure => latest;
      }
      package {
        'python3-testresources':
          ensure => latest;
      }
    }
    default: {
      fail("Cannot install on ${::operatingsystem}")
    }
  }
}
