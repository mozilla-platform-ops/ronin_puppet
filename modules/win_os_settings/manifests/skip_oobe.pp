# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::skip_oobe {
  $oobe_key = "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE"

  registry_value { "${oobe_key}\\HideOOBE":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }

  registry_value { "${oobe_key}\\HideEULAPage":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\HideLocalAccountScreen":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\HideOEMRegistrationScreen":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\HideOnlineAccountScreens":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\HideWirelessSetupInOOBE":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\NetworkLocation":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\OEMAppId":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\ProtectYourPC":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\SkipMachineOOBE":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
  registry_value { "${oobe_key}\\SkipUserOOBE":
    ensure => present,
    type   => 'dword',
    data   => 1,
  }
}
