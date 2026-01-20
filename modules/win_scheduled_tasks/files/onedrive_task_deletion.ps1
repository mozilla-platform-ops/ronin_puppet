<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
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

Remove-OneDriveScheduledTasks
