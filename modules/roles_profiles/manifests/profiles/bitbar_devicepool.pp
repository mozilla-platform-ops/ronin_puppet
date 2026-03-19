# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::bitbar_devicepool {
  case $facts['os']['name'] {
    'Ubuntu': {
      class { 'puppet::run_script':
        puppet_repo   => 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
        puppet_branch => 'master',
      }

      include bitbar_devicepool
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
