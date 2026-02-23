# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::python3_mercurial {
  require linux_packages::py3

  # block for ubuntu and then selecting between 24.04 and 18.04,22.04
  case $facts['os']['name'] {
    'Ubuntu': {
      # 24 install via apt, 18 and 22 install via pip3
      if $facts['os']['release']['full'] == '24.04' {
        # latest is 6.7.2 as of 07182025
        # package { 'mercurial':
        #   ensure   => latest,
        #   provider => apt,
        #   require  => Class['linux_packages::py3'],
        # }
        # install via linux_packages/manifests/mercurial.pp
      } elsif $facts['os']['release']['full'] in ['18.04', '20.04', '22.04'] {
        package { 'python3-mercurial':
          ensure   => '6.4.5',
          name     => 'mercurial',
          provider => pip3,
          require  => Class['linux_packages::py3'],
        }
      }
      else {
        fail("Cannot install python3_mercurial on ${facts['os']['name']} ${facts['os']['release']['major']}")
      }
    }
    default: {
      fail("Cannot install python3_mercurial on ${facts['os']['name']}")
    }
  }
}
