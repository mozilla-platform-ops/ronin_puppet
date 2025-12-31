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

function Ensure-OneDriveTaskCleanupHardeningTask {
    [CmdletBinding()]
    param()

    $dir  = 'C:\ProgramData\Hardening'
    $file = Join-Path $dir 'Remove-OneDriveScheduledTasks.ps1'

    Write-Log -message "OneDriveTasksHardening :: begin" -severity 'DEBUG'

    try {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        # Minimal self-contained script: uses schtasks.exe only and writes to Event Log using your source/logName.
        $payload = @'
function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'MaintainSystem',
        [string] $logName = 'Application'
    )
    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source
        }
        switch ($severity) {
            'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
            'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
            'ERROR' { $entryType = 'Error';        $eventId = 4; break }
            default { $entryType = 'Information';  $eventId = 1; break }
        }
        Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    } catch { }
}

try {
    $rows = @(schtasks.exe /Query /FO CSV /V 2>$null | ConvertFrom-Csv)
    $targets = $rows | Where-Object {
        ($_.TaskName -match '(?i)onedrive') -or
        (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)onedrive(\\.exe)?')) -or
        (($_.Actions) -and ($_.Actions -match '(?i)onedrive(\\.exe)?')) -or
        (($_.'Task Run') -and (($_.'Task Run') -match '(?i)onedrive(\\.exe)?')) -or
        (($_.Actions) -and ($_.Actions -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe')) -or
        (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe'))
    } | Select-Object -ExpandProperty TaskName -Unique

    foreach ($tn in $targets) {
        schtasks.exe /Delete /TN "$tn" /F 2>$null | Out-Null
    }

    Write-Log -message ("OneDriveTasksHardening :: removed {0} task(s)" -f ($targets.Count)) -severity 'INFO'
} catch {
    Write-Log -message ("OneDriveTasksHardening :: failed: {0}" -f $_.Exception.Message) -severity 'WARN'
}
'@

        Set-Content -Path $file -Value $payload -Encoding UTF8 -Force

        $taskName = 'Remove-OneDriveScheduledTasks'
        $taskPath = '\Hardening\'

        schtasks.exe /Delete /TN "$taskPath$taskName" /F 2>$null | Out-Null

        # Create: AtStartup
        schtasks.exe /Create /F /TN "$taskPath$taskName" `
            /SC ONSTART /RU SYSTEM /RL HIGHEST `
            /TR "powershell.exe -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$file`"" `
            2>$null | Out-Null

        # Add a second trigger: AtLogOn (any user)
        schtasks.exe /Create /F /TN "$taskPath$taskName-Logon" `
            /SC ONLOGON /RU SYSTEM /RL HIGHEST `
            /TR "powershell.exe -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$file`"" `
            2>$null | Out-Null

        Write-Log -message "OneDriveTasksHardening :: installed (ONSTART + ONLOGON)" -severity 'INFO'
    }
    catch {
        Write-Log -message ("OneDriveTasksHardening :: failed: {0}" -f $_.Exception.Message) -severity 'WARN'
    }
    finally {
        Write-Log -message "OneDriveTasksHardening :: end" -severity 'DEBUG'
    }
}

function Remove-OneDriveScheduledTasks {
    [CmdletBinding()]
    param()

    Write-Log -message "OneDriveTasks :: begin" -severity 'DEBUG'

    try {
        $rows = @(schtasks.exe /Query /FO CSV /V 2>$null | ConvertFrom-Csv)

        if (-not $rows -or $rows.Count -eq 0) {
            Write-Log -message "OneDriveTasks :: schtasks returned no rows" -severity 'WARN'
            return
        }

        # Columns vary a bit across Windows builds, so check multiple possible fields.
        $targets = $rows | Where-Object {
            ($_.TaskName -match '(?i)onedrive') -or
            (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)onedrive(\\.exe)?')) -or
            (($_.Actions) -and ($_.Actions -match '(?i)onedrive(\\.exe)?')) -or
            (($_.'Task Run') -and (($_.'Task Run') -match '(?i)onedrive(\\.exe)?')) -or
            # extra-tight match on known binaries
            (($_.Actions) -and ($_.Actions -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe')) -or
            (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe'))
        } | Select-Object -ExpandProperty TaskName -Unique

        if (-not $targets -or $targets.Count -eq 0) {
            Write-Log -message "OneDriveTasks :: No matching tasks found" -severity 'DEBUG'
            return
        }

        Write-Log -message ("OneDriveTasks :: Found {0} task(s) to remove" -f $targets.Count) -severity 'INFO'

        foreach ($tn in $targets) {
            try {
                schtasks.exe /Delete /TN "$tn" /F 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log -message ("OneDriveTasks :: Deleted {0}" -f $tn) -severity 'INFO'
                } else {
                    Write-Log -message ("OneDriveTasks :: Failed delete {0} (exit {1})" -f $tn, $LASTEXITCODE) -severity 'WARN'
                }
            } catch {
                Write-Log -message ("OneDriveTasks :: Exception deleting {0}: {1}" -f $tn, $_.Exception.Message) -severity 'WARN'
            }
        }
    }
    catch {
        Write-Log -message ("OneDriveTasks :: failed: {0}" -f $_.Exception.Message) -severity 'WARN'
    }
    finally {
        Write-Log -message "OneDriveTasks :: end" -severity 'DEBUG'
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
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0 -Force
        Remove-OneDriveScheduledTasks
        Ensure-OneDriveTaskCleanupHardeningTask
    }
    "win_2022" {
        ## Disable Server Manager Dashboard
        Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
    }
    Default {
        Write-Log -message  ('{0} :: Skipping at task user logon for {1}' -f $($MyInvocation.MyCommand.Name),$os_version) -severity 'DEBUG'
    }
}
