# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::nxlog {

$programfilesx86 = $facts['programfilesx86']

    defined_classes::pkg::win_msi_pkg  { 'NXLog-CE':
        pkg             => 'nxlog-ce-2.10.2150.msi',
        install_options => ['/quiet'],
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
