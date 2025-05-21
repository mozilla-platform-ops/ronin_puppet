# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_iaccessible2proxy {
  case $facts['os']['name'] {
    'Windows': {
      win_packages::win_dll { 'IAccessible2proxy':
        dll_name        => 'IAccessible2proxy.dll',
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}

## Bug list
## https://bugzilla.mozilla.org/show_bug.cgi?id=1857116
