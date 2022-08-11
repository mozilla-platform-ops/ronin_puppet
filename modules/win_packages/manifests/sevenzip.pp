# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::sevenzip {
  if $facts['os']['name'] == 'Windows' {
    win_packages::win_msi_pkg { '7-Zip 18.06 (x64 edition)':
      pkg             => '7z1806-x64.msi',
      install_options => ['/quiet'],
    }
  } else {
    fail("${module_name} does not support ${$facts['os']['name']}")
  }
}
