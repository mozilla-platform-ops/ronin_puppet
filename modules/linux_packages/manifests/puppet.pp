# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::puppet {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04':  {
          # TODO: write this

          # package {
          #   'nodejs':
          #     ensure => latest;
          #   'nodejs-legacy':
          #     ensure => absent,
          #     before => Package['nodejs'];
          # }

          # for 1804
          #wget https://apt.puppetlabs.com/puppet6-release-bionic.deb
          #sudo dpkg -i puppet6-release-bionic.deb

          #  package { 'yourpackagename':
          #     ensure => installed|absent,
          #     provider => dpkg,
          #     source => '/path/to/file.deb',
          #   }

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
