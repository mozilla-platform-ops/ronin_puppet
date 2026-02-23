# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_sync_from_cloud {

  # GPO: Computer Configuration > Administrative Templates > Windows Components > Sync your settings > Do not sync
  # Registry: HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync
  # Effect: turns off "Remember my preferences" and none of the preferences are synced. :contentReference[oaicite:1]{index=1}

  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync':
    ensure => present,
  }

  # DisableSettingSync: 2 = disable
  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync\DisableSettingSync':
    ensure => present,
    type   => dword,
    data   => '2',
  }

  # DisableSettingSyncUserOverride: 1 = prevent user override (keeps it off)
  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync\DisableSettingSyncUserOverride':
    ensure => present,
    type   => dword,
    data   => '1',
  }
}
