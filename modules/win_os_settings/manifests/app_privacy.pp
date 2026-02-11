# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::app_privacy {

  $app_privacy_key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'

  registry_key { $app_privacy_key:
    ensure => present,
  }

  registry_value { "${app_privacy_key}\\LetAppsAccessMicrophone":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
}
