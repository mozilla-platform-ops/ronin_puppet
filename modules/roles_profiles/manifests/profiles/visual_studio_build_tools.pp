# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::visual_studio_build_tools {
  case $facts['os']['name'] {
    'Windows': {
      $srcloc = lookup('windows.ext_pkg_src')
      case $facts['custom_win_os_version'] {
        'win_2022_2009','win_11_2009': {
          class { 'win_packages::vs_buildtools_2022':
            srcloc => $srcloc,
          }
        }
        default: {
          class { 'win_packages::vs_build_tools':
            srcloc => $srcloc,
          }
        }
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
