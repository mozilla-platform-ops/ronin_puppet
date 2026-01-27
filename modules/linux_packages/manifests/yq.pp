# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# handles installation of mercurial on linux (via pkg and pip)
# - no absent support since 1804 is messy
class linux_packages::yq ( Enum['present'] $pkg_ensure = 'present') {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04': {
          # on 18.04 and 22.04, use the python package
          package { 'jq':
            ensure   => latest,
            provider => 'pip3',
            require  => Class['linux_packages::py3'],
          }
        }
        '24.04': {
          package {
            'yq':
              ensure => $pkg_ensure;
          }
        }
        default: {
          fail("Ubuntu ${facts['os']['release']['full']} is not supported")
        }
      }
    }
    default: {
      fail("Cannot install on ${facts['os']['name']}")
    }
  }
}
