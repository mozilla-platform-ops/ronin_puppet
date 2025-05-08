# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_dll_iaccessible2_proxy {
  case $facts['os']['name'] {
    'Windows': {
      case $facts['custom_win_location'] {
        'datacenter': {
          $srcloc = lookup('windows.s3.ext_pkg_src')
        }
        default: {
          $srcloc = lookup('windows.ext_pkg_src')
        }
      }

      class { 'win_packages::windows_dll_iaccessible2_proxy' :
        file     => "${srcloc}/IAccessible2proxy.dll",
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}

## Bug list
## https://bugzilla.mozilla.org/show_bug.cgi?id=1857116
