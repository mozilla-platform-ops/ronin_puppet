# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::psutil_py3 {
  require linux_packages::py3

  # if ubuntu 2204 install the apt python3-psutil, eslse install psutil via pip3
  case $facts['os']['name'] {
    'Ubuntu': {
      # 24 install via apt, 18 and 22 install via pip3
      if $facts['os']['release']['full'] == '24.04' {
        # latest is 5.9.8 as of 07182025
        package { 'python3-psutil':
          ensure   => latest,
          provider => apt,
          require  => Class['linux_packages::py3'],
        }
      } elsif $facts['os']['release']['full'] in ['18.04', '20.04', '22.04'] {
        package { 'psutil_py3':
          ensure   => '5.9.3',
          name     => 'psutil',
          provider => pip3,
          require  => Class['linux_packages::py3'],
        }
      }
      else {
        fail("Cannot install psutil_py3 on ${facts['os']['name']} ${facts['os']['release']['major']}")
      }
    }
    default: {
      fail("Cannot install psutil_py3 on ${facts['os']['name']}")
    }
  }
}
