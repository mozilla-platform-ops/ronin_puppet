# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::windows_dll_iaccessible2_proxy {
  exec { 'install_dll':
    command  => file('win_packages/install_iaccessible2.ps1'),
    provider => powershell,
  }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1570767
# https://bugzilla.mozilla.org/show_bug.cgi?id=1876822
