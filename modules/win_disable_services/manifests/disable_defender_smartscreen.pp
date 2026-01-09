# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_defender_smartscreen {

  # 1) Windows shell / Explorer SmartScreen ("Check apps and files")
  # HKLM\SOFTWARE\Policies\Microsoft\Windows\System
  #   EnableSmartScreen (DWORD): 0=Off, 1=On
  #   ShellSmartScreenLevel (REG_SZ): Warn/Block when enabled
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

  # 2) Microsoft Edge SmartScreen
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Edge':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Edge\SmartScreenEnabled':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  # 3) SmartScreen for Microsoft Store apps (web content evaluation)
  # (Commonly controlled via EnableWebContentEvaluation)
  registry_key { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost\EnableWebContentEvaluation':
    ensure => present,
    type   => dword,
    data   => '0',
  }
}
