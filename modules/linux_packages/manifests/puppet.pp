# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::puppet {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04':  {

          include apt

          # remove puppet 5 repo, puppet-agent, and puppet if present
          # - will conflict later if not removed
          package { 'remove old puppet repo deb':
            ensure => purged,
            name   => 'puppet5-release',
          }

          # puppet 7 is out, this explodes now
          package { 'remove old puppet repo deb, 2':
            ensure => purged,
            name   => 'puppet6-release',
          }

          package { 'remove old puppet-agent deb':
            ensure => purged,
            name   => 'puppet5-agent',
          }

          # we don't need the full package and it conflicts with puppet-agent
          package { 'remove puppet deb':
            ensure => purged,
            name   => 'puppet',
          }

          # fetch and install the new repo deb
          file { 'puppet_repo_deb':
              ensure => 'file',
              path   => '/tmp/puppet.deb',
              mode   => 'a+r',
              source => 'https://apt.puppetlabs.com/puppet-release-bionic.deb',
          }

          package { 'puppet repo deb':
            ensure   => installed,
            provider => dpkg,
            source   => '/tmp/puppet.deb',
            notify   => Exec['apt_update'],
          }

          # install latest puppet-agent
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
