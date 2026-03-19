# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# handles installation of mercurial on linux (via pkg and pip)
# - no absent support since 1804 is messy
class linux_packages::yqer ( Enum['present'] $pkg_ensure = 'present') {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          # we need python3-yaml for yq-er to work properly
          package { 'python3-yaml':
            ensure => $pkg_ensure;
          }

          # place the the yq-er.sh file in ../files
          file { '/usr/local/bin/yq-er':
            ensure  => file,
            source  => 'puppet:///modules/linux_packages/yq-er.sh',
            mode    => '0755',
            require => Class['linux_packages::py3'],
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
