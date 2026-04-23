# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::skip_oobe {
  $oobe_key = "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE"

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

  # Bug 2026458: Suppress first-logon animation and "Get Started" / privacy
  # experience windows that pop open on AVD SKU images. These windows occlude
  # Firefox test windows, causing the compositor to pause and reftests to
  # time out waiting for MozAfterPaint.

  # Disable the first-logon animation overlay
  $system_policies_key = "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System"
  registry_value { "${system_policies_key}\\EnableFirstLogonAnimation":
    ensure => present,
    type   => 'dword',
    data   => 0,
  }

  $winlogon_key = "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon"
  registry_value { "${winlogon_key}\\EnableFirstLogonAnimation":
    ensure => present,
    type   => 'dword',
    data   => 0,
  }

  # Disable the privacy experience dialog on first login
  $oobe_policies_key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE'
  registry_key { $oobe_policies_key:
    ensure => present,
  }
  registry_value { "${oobe_policies_key}\\DisablePrivacyExperience":
    ensure  => present,
    type    => 'dword',
    data    => 1,
    require => Registry_key[$oobe_policies_key],
  }

  # Suppress Content Delivery Manager "Get Started" and "Welcome" suggestions
  $cdm_key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
  registry_key { $cdm_key:
    ensure => present,
  }
  registry_value { "${cdm_key}\\DisableWindowsConsumerFeatures":
    ensure  => present,
    type    => 'dword',
    data    => 1,
    require => Registry_key[$cdm_key],
  }
  registry_value { "${cdm_key}\\DisableSoftLanding":
    ensure  => present,
    type    => 'dword',
    data    => 1,
    require => Registry_key[$cdm_key],
  }
  registry_value { "${cdm_key}\\DisableCloudOptimizedContent":
    ensure  => present,
    type    => 'dword',
    data    => 1,
    require => Registry_key[$cdm_key],
  }
}
