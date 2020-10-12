# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This installs the system git, which is basically whatever version that
# OS provides.

class linux_packages::system_git {

  case $::operatingsystem {
    'Ubuntu': {
      package {
        'git':
          ensure => latest;
      }
    }
    default: {
      fail("Cannot install on ${::operatingsystem}")
    }
  }
}
