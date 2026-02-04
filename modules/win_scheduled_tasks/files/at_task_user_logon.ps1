## Set variable for windows OS
# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

<#
NOTE: This script is specific for items that can't be done until the user environment is in place.
#>

function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'MaintainSystem',
        [string] $logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }
    switch ($severity) {
        'DEBUG' {
            $entryType = 'SuccessAudit'
            $eventId = 2
            break
        }
        'WARN' {
            $entryType = 'Warning'
            $eventId = 3
            break
        }
        'ERROR' {
            $entryType = 'Error'
            $eventId = 4
            break
        }
        default {
            $entryType = 'Information'
            $eventId = 1
            break
        }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host -object $message -ForegroundColor $fc
    }
}

# Windows release ID.
# From time to time we need to have the different releases of the same OS version
$release_key = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')
$release_id = $release_key.ReleaseId
$caption = ((Get-WmiObject Win32_OperatingSystem).caption)
$caption = $caption.ToLower()
$os_caption = $caption -replace ' ', '_'

if ($os_caption -like "*windows_10*") {
    $os_version = ( -join ( "win_10_", $release_id))
}
elseif ($os_caption -like "*windows_11*") {
    $os_version = ( -join ( "win_11_", $release_id))
}
elseif ($os_caption -like "*2012*") {
    $os_version = "win_2012"
}
elseif ($os_caption -like "*2022*") {
    $os_version = "win_2022"
}
else {
    $os_version = $null
}

## Wait until explorer is set in the registry and then suppress notifications for firewall
while ($true) {
    $explorer = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction SilentlyContinue
    if ($null -eq $explorer) {
        Start-Sleep -Seconds 3
    }
    else {
        ## Tested against windows 11
        cmd.exe /c 'netsh firewall set notifications mode = disable profile = all'
        break
    }
}

## Accessibilty keys in HKCU
$Accessibility = Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility"

## Show scrollbars permanently
switch ($os_version) {
    "win_10_2009" {
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0 -Force
    }
    "win_11_2009" {

        # Signal to bootstrap/runner that user-init has started (and should complete before tests)
        try {
            [Environment]::SetEnvironmentVariable('MOZ_GW_UI_READY', '0', 'Machine')
            Write-Log -message "MOZ_GW_UI_READY :: set to 0 (user-init starting)" -severity 'DEBUG'
        } catch {
            Write-Log -message ("MOZ_GW_UI_READY :: failed to set 0: {0}" -f $_.Exception.Message) -severity 'WARN'
        }

        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0 -Force

        if ($worker_location -eq 'MDC1 hardware') {
            if ($env:USERNAME -match 'administrator') {
                exit
            } else {
                Disable-PerUserUwpServices
                Remove-OneDriveScheduledTasks
                Disable-OneDriveBackupPopup
                Remove-EdgeScheduledTasks
                ## Not currently functioning
                #Disable-SyncFromCloud
                #Disable-SmartScreenStoreApps
                explorer.exe shell::: { 3080F90D-D7AD-11D9-BD98-0000947B0257 } -Verb MinimizeAll
                Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
                taskkill /f /im StartMenuExperienceHost.exe
            }
        }

        # Signal complete
        try {
            [Environment]::SetEnvironmentVariable('MOZ_GW_UI_READY', '1', 'Machine')
            Write-Log -message "MOZ_GW_UI_READY :: set to 1 (user-init complete)" -severity 'INFO'
        } catch {
            Write-Log -message ("MOZ_GW_UI_READY :: failed to set 1: {0}" -f $_.Exception.Message) -severity 'WARN'
        }
    }
    "win_2022" {
        ## Disable Server Manager Dashboard
        Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
    }
    Default {
        Write-Log -message  ('{0} :: Skipping at task user logon for {1}' -f $($MyInvocation.MyCommand.Name),$os_version) -severity 'DEBUG'
    }
}
