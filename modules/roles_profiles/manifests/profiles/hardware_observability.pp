# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::hardware_observability {
  case $facts['os']['name'] {
    'Windows': {
        class { win_nsclient::init:
            server    => lookup('windows.datacenter.marlin.ip'),
            server_pw => lookup('marlin_pw')
        }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
