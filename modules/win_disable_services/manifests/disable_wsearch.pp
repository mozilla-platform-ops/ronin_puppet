# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_wsearch {
  if $facts['os']['name'] == 'Windows' {
    exec { 'disable_wsearch':
      command  => file('win_disable_services/wsearch/disable.ps1'),
      provider => powershell,
      timeout  => 300,
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
