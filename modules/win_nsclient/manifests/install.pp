# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nsclient::install {

    win_packages::win_msi_pkg  { 'nsclient':
        pkg             => 'NSCP-0.9.15-x64.msi',
        install_options => ['/quiet'],
    }
}
