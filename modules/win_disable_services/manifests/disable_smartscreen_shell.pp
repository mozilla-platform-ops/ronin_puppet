# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_smartscreen_shell {

  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System\EnableSmartScreen':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System\ShellSmartScreenLevel':
    ensure => absent,
  }
}
