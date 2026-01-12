# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_defender_smartscreen {

  ## Windows Shell / Explorer SmartScreen ("Check apps and files") POLICY
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

  ## Explorer non-policy setting (per NinjaOne)
  registry_key { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer':
    ensure => present,
  }

  ## Values: "Off", "Warn", "RequireAdmin"
  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled':
    ensure => present,
    type   => string,
    data   => 'Off',
  }

  ## Microsoft Edge SmartScreen (Edge policy registry path)
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Edge':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Edge\SmartScreenEnabled':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  ## disable Edge PUA reputation as well
  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Edge\SmartScreenPuaEnabled':
    ensure => present,
    type   => dword,
    data   => '0',
  }
}
