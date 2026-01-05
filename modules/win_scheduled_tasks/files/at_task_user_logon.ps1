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

function Remove-OneDriveScheduledTasks {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 180,
        [int]$RetryIntervalSeconds = 10,
        [int]$PerTaskDeleteTimeoutSeconds = 60,
        [int]$PerTaskRetryIntervalSeconds = 3
    )
    ## give it a minute to for schd task to be available
    start-sleep -s 60
    function Get-OneDriveTaskNames {
        try {
            $rows = @(schtasks.exe /Query /FO CSV /V 2>$null | ConvertFrom-Csv)
            if (-not $rows -or $rows.Count -eq 0) { return @() }

            $matches = $rows | Where-Object {
                ($_.TaskName -match '(?i)onedrive') -or
                (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)onedrive(\\.exe)?')) -or
                (($_.Actions) -and ($_.Actions -match '(?i)onedrive(\\.exe)?')) -or
                (($_.'Task Run') -and (($_.'Task Run') -match '(?i)onedrive(\\.exe)?')) -or
                (($_.Actions) -and ($_.Actions -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe')) -or
                (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe'))
            }

            return @($matches | Select-Object -ExpandProperty TaskName -Unique)
        }
        catch {
            Write-Log -message ("OneDriveTasks :: enumerate failed: {0}" -f $_.Exception.Message) -severity 'WARN'
            return @()
        }
    }

    function Test-TaskExists([string]$TaskName) {
        try {
            schtasks.exe /Query /TN "$TaskName" 1>$null 2>$null
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $true  # assume it exists if we couldn't query
        }
    }

    function Remove-TaskWithRetries {
        param(
            [Parameter(Mandatory)][string]$TaskName
        )

        $deadline = (Get-Date).AddSeconds($PerTaskDeleteTimeoutSeconds)
        $attempt  = 0

        while ((Get-Date) -lt $deadline) {
            $attempt++

            try {
                schtasks.exe /Delete /TN "$TaskName" /F 2>$null | Out-Null
                $exit = $LASTEXITCODE

                if ($exit -eq 0) {
                    # Some tasks "delete" but linger briefly; verify
                    if (-not (Test-TaskExists -TaskName $TaskName)) {
                        Write-Log -message ("OneDriveTasks :: deleted {0} (attempt {1})" -f $TaskName, $attempt) -severity 'INFO'
                        return $true
                    }

                    Write-Log -message ("OneDriveTasks :: delete reported success but task still exists: {0} (attempt {1})" -f $TaskName, $attempt) -severity 'WARN'
                } else {
                    Write-Log -message ("OneDriveTasks :: delete failed {0} (exit {1}, attempt {2})" -f $TaskName, $exit, $attempt) -severity 'WARN'
                }
            }
            catch {
                Write-Log -message ("OneDriveTasks :: exception deleting {0} (attempt {1}): {2}" -f $TaskName, $attempt, $_.Exception.Message) -severity 'WARN'
            }

            Start-Sleep -Seconds $PerTaskRetryIntervalSeconds
        }

        Write-Log -message ("OneDriveTasks :: timeout deleting {0} after {1}s" -f $TaskName, $PerTaskDeleteTimeoutSeconds) -severity 'ERROR'
        return $false
    }

    Write-Log -message ("OneDriveTasks :: begin (timeout={0}s, interval={1}s, perTaskTimeout={2}s)" -f $TimeoutSeconds, $RetryIntervalSeconds, $PerTaskDeleteTimeoutSeconds) -severity 'DEBUG'

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $pass = 0

    while ((Get-Date) -lt $deadline) {
        $pass++
        $targets = Get-OneDriveTaskNames

        if (-not $targets -or $targets.Count -eq 0) {
            Write-Log -message ("OneDriveTasks :: none found (pass {0})" -f $pass) -severity 'INFO'
            Write-Log -message "OneDriveTasks :: end (success)" -severity 'DEBUG'
            return
        }

        Write-Log -message ("OneDriveTasks :: pass {0}: found {1} task(s)" -f $pass, $targets.Count) -severity 'INFO'

        foreach ($tn in $targets) {
            $null = Remove-TaskWithRetries -TaskName $tn
        }

        # Re-check right away; if still present, sleep and retry until overall timeout
        $stillThere = Get-OneDriveTaskNames
        if (-not $stillThere -or $stillThere.Count -eq 0) {
            Write-Log -message ("OneDriveTasks :: verification OK after pass {0}" -f $pass) -severity 'INFO'
            Write-Log -message "OneDriveTasks :: end (success)" -severity 'DEBUG'
            return
        }

        $remaining = [math]::Max(0, [int]($deadline - (Get-Date)).TotalSeconds)
        Write-Log -message ("OneDriveTasks :: still present after pass {0} (remaining {1}s). Sleeping {2}s..." -f $pass, $remaining, $RetryIntervalSeconds) -severity 'WARN'
        Start-Sleep -Seconds $RetryIntervalSeconds
    }

    $final = Get-OneDriveTaskNames
    if ($final -and $final.Count -gt 0) {
        $sample = ($final | Select-Object -First 10) -join '; '
        Write-Log -message ("OneDriveTasks :: timeout after {0}s. Remaining task(s): {1}" -f $TimeoutSeconds, $sample) -severity 'ERROR'
    } else {
        Write-Log -message "OneDriveTasks :: end (success at timeout boundary)" -severity 'INFO'
    }
}

function Disable-PerUserUwpServices {
    [CmdletBinding()]
    param (
        [string[]]
        $ServicePrefixes = @(
            'cbdhsvc_',                 # Clipboard User Service
            'OneSyncSvc_',              # Sync Host
            'UdkUserSvc_',              # Udk User Service
            'PimIndexMaintenanceSvc_',  # Contact/People indexing
            'UnistoreSvc_',             # User Data Storage
            'UserDataSvc_',             # User Data Access
            'CDPUserSvc_',              # Connected Devices Platform (user)
            'WpnUserService_',          # Push Notifications (user)
            'webthreatdefusersvc_'      # Web Threat Defense (user)
        )
    )

    foreach ($prefix in $ServicePrefixes) {

        $svcList = Get-Service -Name "$prefix*" -ErrorAction SilentlyContinue

        if (-not $svcList) {
            Write-Log -message ('{0} :: No services found for prefix {1}' -f $($MyInvocation.MyCommand.Name), $prefix) -severity 'DEBUG'
            continue
        }

        foreach ($svc in $svcList) {
            try {
                if ($svc.Status -eq 'Running') {
                    Write-Log -message ('{0} :: Stopping per-user service {1}' -f $($MyInvocation.MyCommand.Name), $svc.Name) -severity 'DEBUG'
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                }
                else {
                    Write-Log -message ('{0} :: Service {1} is already {2}, no action needed' -f $($MyInvocation.MyCommand.Name), $svc.Name, $svc.Status) -severity 'DEBUG'
                }
            }
            catch {
                Write-Log -message ('{0} :: Failed to stop service {1}: {2}' -f $($MyInvocation.MyCommand.Name), $svc.Name, $_.Exception.Message) -severity 'DEBUG'
            }
        }
    }
}

function Remove-EdgeScheduledTasks {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 180,
        [int]$RetryIntervalSeconds = 10,
        [int]$PerTaskDeleteTimeoutSeconds = 60,
        [int]$PerTaskRetryIntervalSeconds = 3
    )

    # Match only the common Edge updater tasks (keeps this "safe-simple")
    $NamePatterns = @(
        '(?i)\\MicrosoftEdgeUpdateTaskMachineCore',
        '(?i)\\MicrosoftEdgeUpdateTaskMachineUA',
        '(?i)\\MicrosoftEdgeUpdateTaskMachine',     # some builds vary
        '(?i)\\EdgeUpdate'                          # fallback
    )

    $ActionPatterns = @(
        '(?i)msedgeupdate\.exe',
        '(?i)microsoftedgeupdate\.exe',
        '(?i)edgeupdate\.exe'
    )

    function Get-EdgeTaskNames {
        try {
            $rows = @(schtasks.exe /Query /FO CSV /V 2>$null | ConvertFrom-Csv)
            if (-not $rows -or $rows.Count -eq 0) { return @() }

            $matches = $rows | Where-Object {
                $tn = $_.TaskName
                $a1 = $_.'Task To Run'
                $a2 = $_.Actions
                $a3 = $_.'Task Run'

                ($NamePatterns | Where-Object { $tn -match $_ }).Count -gt 0 -or
                (($a1 -and (($ActionPatterns | Where-Object { $a1 -match $_ }).Count -gt 0))) -or
                (($a2 -and (($ActionPatterns | Where-Object { $a2 -match $_ }).Count -gt 0))) -or
                (($a3 -and (($ActionPatterns | Where-Object { $a3 -match $_ }).Count -gt 0)))
            }

            return @($matches | Select-Object -ExpandProperty TaskName -Unique)
        }
        catch {
            Write-Log -message ("EdgeTasks :: enumerate failed: {0}" -f $_.Exception.Message) -severity 'WARN'
            return @()
        }
    }

    function Test-TaskExists([string]$TaskName) {
        try {
            schtasks.exe /Query /TN "$TaskName" 1>$null 2>$null
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $true
        }
    }

    function Remove-TaskWithRetries {
        param(
            [Parameter(Mandatory)][string]$TaskName
        )

        $deadline = (Get-Date).AddSeconds($PerTaskDeleteTimeoutSeconds)
        $attempt  = 0

        while ((Get-Date) -lt $deadline) {
            $attempt++

            try {
                schtasks.exe /Delete /TN "$TaskName" /F 2>$null | Out-Null
                $exit = $LASTEXITCODE

                if ($exit -eq 0) {
                    if (-not (Test-TaskExists -TaskName $TaskName)) {
                        Write-Log -message ("EdgeTasks :: deleted {0} (attempt {1})" -f $TaskName, $attempt) -severity 'INFO'
                        return $true
                    }
                    Write-Log -message ("EdgeTasks :: delete reported success but task still exists: {0} (attempt {1})" -f $TaskName, $attempt) -severity 'WARN'
                } else {
                    Write-Log -message ("EdgeTasks :: delete failed {0} (exit {1}, attempt {2})" -f $TaskName, $exit, $attempt) -severity 'WARN'
                }
            }
            catch {
                Write-Log -message ("EdgeTasks :: exception deleting {0} (attempt {1}): {2}" -f $TaskName, $attempt, $_.Exception.Message) -severity 'WARN'
            }

            Start-Sleep -Seconds $PerTaskRetryIntervalSeconds
        }

        Write-Log -message ("EdgeTasks :: timeout deleting {0} after {1}s" -f $TaskName, $PerTaskDeleteTimeoutSeconds) -severity 'ERROR'
        return $false
    }

    Write-Log -message ("EdgeTasks :: begin (timeout={0}s, interval={1}s, perTaskTimeout={2}s)" -f $TimeoutSeconds, $RetryIntervalSeconds, $PerTaskDeleteTimeoutSeconds) -severity 'DEBUG'

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $pass = 0

    while ((Get-Date) -lt $deadline) {
        $pass++
        $targets = Get-EdgeTaskNames

        if (-not $targets -or $targets.Count -eq 0) {
            Write-Log -message ("EdgeTasks :: none found (pass {0})" -f $pass) -severity 'INFO'
            Write-Log -message "EdgeTasks :: end (success)" -severity 'DEBUG'
            return
        }

        Write-Log -message ("EdgeTasks :: pass {0}: found {1} task(s)" -f $pass, $targets.Count) -severity 'INFO'

        foreach ($tn in $targets) {
            $null = Remove-TaskWithRetries -TaskName $tn
        }

        $stillThere = Get-EdgeTaskNames
        if (-not $stillThere -or $stillThere.Count -eq 0) {
            Write-Log -message ("EdgeTasks :: verification OK after pass {0}" -f $pass) -severity 'INFO'
            Write-Log -message "EdgeTasks :: end (success)" -severity 'DEBUG'
            return
        }

        $remaining = [math]::Max(0, [int]($deadline - (Get-Date)).TotalSeconds)
        Write-Log -message ("EdgeTasks :: still present after pass {0} (remaining {1}s). Sleeping {2}s..." -f $pass, $remaining, $RetryIntervalSeconds) -severity 'WARN'
        Start-Sleep -Seconds $RetryIntervalSeconds
    }

    $final = Get-EdgeTaskNames
    if ($final -and $final.Count -gt 0) {
        $sample = ($final | Select-Object -First 10) -join '; '
        Write-Log -message ("EdgeTasks :: timeout after {0}s. Remaining task(s): {1}" -f $TimeoutSeconds, $sample) -severity 'ERROR'
    } else {
        Write-Log -message "EdgeTasks :: end (success at timeout boundary)" -severity 'INFO'
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
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0 -Force
        Disable-PerUserUwpServices
        Remove-OneDriveScheduledTasks
        Remove-EdgeScheduledTasks
    }
    "win_2022" {
        ## Disable Server Manager Dashboard
        Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
    }
    Default {
        Write-Log -message  ('{0} :: Skipping at task user logon for {1}' -f $($MyInvocation.MyCommand.Name),$os_version) -severity 'DEBUG'
    }
}
