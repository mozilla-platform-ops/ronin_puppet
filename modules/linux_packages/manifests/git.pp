# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::git {
  case $facts['os']['name'] {
    'Ubuntu': {
                  case $facts['os']['release']['full'] {
                '18.04': {

    package {
              'git':
                  ensure => present;
          }
                    }
                    default: {
                        fail("cannot install on ${facts['os']['release']['full']}")
                    }
                }
    }
    default: {
      fail("Cannot install on ${facts['os']['name']}")
    }
  }
}
