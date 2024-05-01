# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_defender {
  if $facts['os']['name'] == 'Windows' {
    ## Taken from https://github.com/mozilla-platform-ops/worker-images/blob/main/scripts/windows/CustomFunctions/Bootstrap/Public/Disable-AntiVirus.ps1 
    exec { 'disable_windows_defender':
      command  => file('win_disable_services/windows_defender/set.ps1'),
      onlyif   => file('win_disable_services/windows_defender/validate.ps1'),
      provider => powershell,
      timeout  => 300,
    }

    ## Taken from https://github.com/mozilla-platform-ops/worker-images/blob/main/scripts/windows/CustomFunctions/Bootstrap/Public/Disable-AntiVirus.ps1
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Windows Advanced Threat Protection\ForceDefenderPassiveMode':
      type => dword,
      data => '1',
    }
  }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1512435
# https://bugzilla.mozilla.org/show_bug.cgi?id=1509722
