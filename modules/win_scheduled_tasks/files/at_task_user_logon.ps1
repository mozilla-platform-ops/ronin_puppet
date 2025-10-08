## Set variable for windows OS
# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

<#
NOTE: This script is specific for items that can't be done until the user environment is in place.
#>

function Disable-OneDrive {
    [CmdletBinding()]
    param (
        
    )

    $ErrorActionPreference = 'SilentlyContinue'

    Stop-Process -Name OneDrive -Force
    Stop-Process -Name OneDriveSetup -Force
    Stop-Process -Name explorer -Force

    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
    New-Item -Path $pol -Force | Out-Null
    New-ItemProperty -Path $pol -Name 'DisableFileSyncNGSC' -PropertyType DWord -Value 1 -Force | Out-Null
    # Clean incorrect Wow6432Node path (if previously set)
    Remove-Item -Path 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive' -Recurse -Force

    foreach ($rk in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        )) {
        if (Test-Path $rk) {
            $props = (Get-ItemProperty -Path $rk | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
            foreach ($name in $props) {
                $val = (Get-ItemPropertyValue -Path $rk -Name $name)
                if ($val -match 'OneDriveSetup\.exe') {
                    Remove-ItemProperty -Path $rk -Name $name -Force
                }
            }
        }
    }

    Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -like 'OneDrive*' -or $_.TaskPath -like '\Microsoft\OneDrive\*' } |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    $sys32 = "$env:WINDIR\System32\OneDriveSetup.exe"
    $wow64 = "$env:WINDIR\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $sys32) { & $sys32 /uninstall }
    if (Test-Path $wow64) { & $wow64 /uninstall }

    Remove-Item -LiteralPath "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force
    Remove-Item -LiteralPath "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force
    Remove-Item -LiteralPath "$env:SYSTEMDRIVE\OneDriveTemp" -Recurse -Force
    if (Test-Path "$env:USERPROFILE\OneDrive") {
        if ((Get-ChildItem "$env:USERPROFILE\OneDrive" -Recurse | Measure-Object).Count -eq 0) {
            Remove-Item -LiteralPath "$env:USERPROFILE\OneDrive" -Recurse -Force
        }
    }

    Start-Process explorer.exe

}

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

## Show scrollbars permanently
switch ($os_version) {
    "win_10_2009" {
        Disable-OneDrive
    }
    "win_11_2009" {
        Disable-OneDrive
    }
    "win_2022" {
        ## Disable Server Manager Dashboard
        Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
    }
    Default {
        Write-Log -message  ('{0} :: Skipping at task user logon for {1}' -f $($MyInvocation.MyCommand.Name),$os_version) -severity 'DEBUG'
    }
}
