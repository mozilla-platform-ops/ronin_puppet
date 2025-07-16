# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::sevenzip {
  case $facts['custom_win_os_arch'] {
    'aarch64': {
      $pkg = '7z2500-arm64.exe'
      win_packages::win_exe_pkg { '7-Zip 25.00 (arm64 edition)':
        pkg                    => $pkg,
        install_options_string => ['/S'],
      }
    }
    default: {
      $pkg = '7z2500-x64.msi'
      win_packages::win_msi_pkg { '7-Zip 25.00 (x64 edition)':
        pkg                    => $pkg,
        install_options => ['/quiet'],
      }
    }
  }
}
