# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Policy-based Windows Defender / real-time protection disable.
#
# IMPORTANT: on Windows 11 with Tamper Protection ENABLED (the state on the
# datacenter hardware fleet, TamperProtectionSource=5, which cannot be turned off
# in-OS), Defender IGNORES these policy values - Tamper Protection guards them.
# They are honored only when Tamper Protection is OFF (e.g. disabled in the image
# before first boot). They declare intent and make the disable correct + immediate
# for any Tamper-off image, but they are NOT sufficient on their own while Tamper
# is on.
#
# The mechanism that actually disables on-access scanning while Tamper is on is the
# driver rename performed by win_disable_services::disable_windows_defender_schtask
# (renames WdFilter/WdBoot/WdNisDrv at boot, below Tamper's reach), re-asserted at
# boot by the maintain-system script (Invoke-DefenderRealtimeGuard), and monitored
# by the win_nsclient check_defender check.
class win_disable_services::disable_windows_defender {
  if $facts['os']['name'] == 'Windows' {
    registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender':
      ensure => present,
    }
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\DisableAntiSpyware':
      ensure => present,
      type   => dword,
      data   => '1',
    }

    registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection':
      ensure => present,
    }
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection\DisableRealtimeMonitoring':
      ensure => present,
      type   => dword,
      data   => '1',
    }
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection\DisableBehaviorMonitoring':
      ensure => present,
      type   => dword,
      data   => '1',
    }
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection\DisableOnAccessProtection':
      ensure => present,
      type   => dword,
      data   => '1',
    }
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection\DisableIOAVProtection':
      ensure => present,
      type   => dword,
      data   => '1',
    }

    # Force Defender into passive mode (honored when Tamper is off / another AV is
    # registered). Harmless otherwise.
    registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection':
      ensure => present,
    }
    registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\ForceDefenderPassiveMode':
      ensure => present,
      type   => dword,
      data   => '1',
    }

    # The following DO take effect even while Tamper Protection is on (verified on the
    # 24h2 hw fleet) - they are not guarded by Tamper Protection the way the AV
    # engine/services/drivers are:

    # Disable the Defender for Endpoint (EDR) sensor service. This is the ONE Defender
    # service whose Start value is writable under Tamper (WinDefend/WdFilter/WdNisSvc are
    # not). 4 = disabled.
    registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\Sense\Start':
      ensure => present,
      type   => dword,
      data   => '4',
    }

    # Disable Defender's built-in scheduled tasks (scans/cleanup/cache/verification) so
    # they cannot fire during CI tasks. Tamper Protection does not protect these.
    exec { 'disable_defender_scheduled_tasks':
      command  => 'Get-ScheduledTask -TaskPath "\\Microsoft\\Windows\\Windows Defender\\" -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null',
      onlyif   => 'if (Get-ScheduledTask -TaskPath "\\Microsoft\\Windows\\Windows Defender\\" -ErrorAction SilentlyContinue | Where-Object { $_.State -ne "Disabled" }) { exit 0 } else { exit 1 }',
      provider => powershell,
    }

    # Blanket on-access path exclusions for the CI volumes (GP-managed; writable and
    # honored under Tamper). These minimise scan overhead during the window where
    # WdFilter is still loaded (e.g. right after a Defender platform update, before the
    # maintain-system guard reboots). They are (re)asserted every boot by
    # Invoke-DefenderRealtimeGuard in maintainsystem-hw.ps1 (value names contain a
    # trailing backslash, which is set there rather than via registry_value titles).
  }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1512435
# https://bugzilla.mozilla.org/show_bug.cgi?id=1509722
