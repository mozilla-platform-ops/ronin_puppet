# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_10_sdk::install {
  exec { 'win10-sdk':
    command   => file('files/install.ps1'),
    onlyif    => file('files/validate.ps1'),
    provider  => powershell,
    logoutput => true,
  }
}
