# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::puppet {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04':  {

          include apt

          $packages_to_purge = [
                                # remove unversioned repo package
                                'puppet-release',
                                # purge older versioned release packages
                                'puppet5-release', 'puppet6-release',
                                # older packages that could be present?
                                'puppet5-agent',
                                # we don't need the full package and it conflicts with puppet-agent
                                'puppet'
                                ]

          package { $packages_to_purge:
              ensure => purged,
          }

          # fetch and install the new repo deb
          file { 'puppet_repo_deb':
              ensure    => 'file',
              path      => '/tmp/puppet.deb',
              mode      => 'a+r',
              source    => 'https://apt.puppetlabs.com/puppet7-release-bionic.deb',
              subscribe => Package[$packages_to_purge],
          }

          package { 'puppet repo deb':
            ensure    => installed,
            provider  => dpkg,
            source    => '/tmp/puppet.deb',
            subscribe => File['puppet_repo_deb']
          }

          # install latest puppet-agent
          package { 'install puppet agent':
            # 1. if changing version, also ensure this is in sync with
            # provisioners/linux/bootstrap_linux.sh
            # 2. if upgrading, make sure to purge the old versioned release deb (see above)
            ensure    => '7.5.0-1bionic',
            name      => 'puppet-agent',
            require   => Exec['apt_update'],
            subscribe => Package['puppet repo deb']
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
