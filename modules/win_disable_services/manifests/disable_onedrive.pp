# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_onedrive {
  exec { 'disable_onedrive':
    command  => file('win_disable_services/disable_onedrive.ps1'),
    provider => powershell,
  }
}
# Bug list
# TODO port script into this manifest
# https://bugzilla.mozilla.org/show_bug.cgi?id=1535228
