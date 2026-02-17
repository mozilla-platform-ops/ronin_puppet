# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nxlog::install {
  case $facts['custom_win_bootstrap_stage'] {
    'complete': {
      notify { "${module_name} not needed since bootstrap stage is complete": }
    }
    default: {
      win_packages::win_msi_pkg { 'NXLog-CE':
        pkg             => 'nxlog-ce-2.10.2150.msi',
        install_options => ['/quiet'],
      }
    }
  }
}
