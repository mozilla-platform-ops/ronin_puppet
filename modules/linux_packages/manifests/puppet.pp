# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::puppet {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04':  {

          include apt

          package { 'remove old puppet repo deb':
            ensure => absent,
            name   => 'puppet5-release',
          }

          package { 'remove old puppet-agent deb':
            ensure => absent,
            name   => 'puppet5-agent',
          }

          file { 'puppet_repo_deb':
              ensure => 'file',
              path   => '/tmp/puppet.deb',
              mode   => 'a+r',
              source => 'https://apt.puppetlabs.com/puppet6-release-bionic.deb',
          }

          package { 'puppet repo deb':
            ensure   => installed,
            provider => dpkg,
            source   => '/tmp/puppet.deb',
            notify   => Exec['apt_update'],
          }

          package { 'install puppet agent':
            ensure => latest,
            name   => 'puppet-agent',
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
