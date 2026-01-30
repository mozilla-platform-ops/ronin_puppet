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

function Disable-OneDriveBackupPopup {
    [CmdletBinding()]
    param()

    Write-Log -message "Disable-OneDriveBackupPopup :: begin" -severity 'INFO'

    try {
        $wb = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsBackup'
        New-Item -Path $wb -Force | Out-Null
        New-ItemProperty -Path $wb -Name 'DisableMonitoring' -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Log -message "Disable-OneDriveBackupPopup :: Set WindowsBackup DisableMonitoring=1" -severity 'INFO'
    } catch {
        Write-Log -message ("Disable-OneDriveBackupPopup :: Failed setting DisableMonitoring: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    try {
        $odPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
        New-Item -Path $odPol -Force | Out-Null
        New-ItemProperty -Path $odPol -Name 'DisableFileSyncNGSC' -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Log -message "Disable-OneDriveBackupPopup :: Set OneDrive DisableFileSyncNGSC=1" -severity 'INFO'
    } catch {
        Write-Log -message ("Disable-OneDriveBackupPopup :: Failed setting DisableFileSyncNGSC: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    try {
        Get-Process -Name OneDrive -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log -message ("Disable-OneDriveBackupPopup :: Stopping OneDrive.exe (Id={0})" -f $_.Id) -severity 'INFO'
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log -message ("Disable-OneDriveBackupPopup :: Failed stopping OneDrive process: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    function Remove-RunEntry([string]$HiveRoot) {
        $runKey = "${HiveRoot}\Software\Microsoft\Windows\CurrentVersion\Run"
        foreach ($name in @('OneDrive','OneDriveSetup','Microsoft OneDrive')) {
            try {
                & reg.exe delete $runKey /v $name /f 1>$null 2>$null
            } catch { }
        }
    }

    $defaultNtUser = 'C:\Users\Default\NTUSER.DAT'
    if (Test-Path $defaultNtUser) {
        try {
            & reg.exe load 'HKU\DefaultUser' $defaultNtUser 1>$null 2>$null
            Remove-RunEntry 'HKU\DefaultUser'
            & reg.exe unload 'HKU\DefaultUser' 1>$null 2>$null
            Write-Log -message "Disable-OneDriveBackupPopup :: Cleared OneDrive Run entries in Default user profile" -severity 'INFO'
        } catch {
            Write-Log -message ("Disable-OneDriveBackupPopup :: Failed editing Default user hive: {0}" -f $_.Exception.Message) -severity 'WARN'
            try { & reg.exe unload 'HKU\DefaultUser' 1>$null 2>$null } catch { }
        }
    } else {
        Write-Log -message "Disable-OneDriveBackupPopup :: Default NTUSER.DAT not found; skipping default profile edit" -severity 'DEBUG'
    }

    try {
        $userSids = @(Get-ChildItem Registry::HKEY_USERS -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^S-1-5-21-' } |
            Select-Object -ExpandProperty PSChildName)

        foreach ($sid in $userSids) {
            Remove-RunEntry ("HKU\{0}" -f $sid)
        }

        Write-Log -message ("Disable-OneDriveBackupPopup :: Cleared OneDrive Run entries in {0} loaded user hive(s)" -f $userSids.Count) -severity 'INFO'
    } catch {
        Write-Log -message ("Disable-OneDriveBackupPopup :: Failed clearing loaded user hives: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    Write-Log -message "Disable-OneDriveBackupPopup :: complete (recommend reboot)" -severity 'INFO'
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

function Disable-SyncFromCloud {
    [CmdletBinding()]
    param()

    Write-Log -message "Disable-SyncFromCloud :: begin (disable Language settings sync)" -severity 'INFO'

    # 1) Always do per-user disable (no admin required)
    try {
        $kUser = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language'
        New-Item -Path $kUser -Force | Out-Null
        New-ItemProperty -Path $kUser -Name 'Enabled' -PropertyType DWord -Value 0 -Force | Out-Null

        $val = (Get-ItemProperty -Path $kUser -Name Enabled -ErrorAction SilentlyContinue).Enabled
        Write-Log -message ("Disable-SyncFromCloud :: HKCU Language sync disabled (Enabled={0})" -f $val) -severity 'INFO'
    }
    catch {
        Write-Log -message ("Disable-SyncFromCloud :: HKCU write failed: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    # 2) If elevated, also enforce via machine policy (optional hard block)
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
                   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            $kPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
            New-Item -Path $kPol -Force | Out-Null

            # Common policy convention: 2 = disable
            New-ItemProperty -Path $kPol -Name 'DisableLanguageSettingSync' -PropertyType DWord -Value 2 -Force | Out-Null

            $pval = (Get-ItemProperty -Path $kPol -Name DisableLanguageSettingSync -ErrorAction SilentlyContinue).DisableLanguageSettingSync
            Write-Log -message ("Disable-SyncFromCloud :: HKLM policy set DisableLanguageSettingSync={0}" -f $pval) -severity 'INFO'
        }
        else {
            Write-Log -message "Disable-SyncFromCloud :: not elevated; skipping HKLM policy enforcement" -severity 'DEBUG'
        }
    }
    catch {
        Write-Log -message ("Disable-SyncFromCloud :: HKLM policy step failed: {0}" -f $_.Exception.Message) -severity 'DEBUG'
    }

    Write-Log -message "Disable-SyncFromCloud :: complete (recommend sign out/in or reboot)" -severity 'INFO'
}

function Disable-SmartScreenStoreApps {
    [CmdletBinding()]
    param()

    Write-Log -message "Disable-SmartScreenStoreApps :: begin (disable SmartScreen for Microsoft Store apps)" -severity 'INFO'

    # Helper: normalize raw registry root strings to a PowerShell registry provider path
    function Convert-ToRegistryProviderPath {
        param([Parameter(Mandatory)][string]$Path)

        switch -Regex ($Path) {
            '^HKLM:\\' { return $Path }
            '^HKCU:\\' { return $Path }
            '^HKEY_LOCAL_MACHINE\\' { return "Registry::$Path" }
            '^HKEY_CURRENT_USER\\'  { return "Registry::$Path" }
            default { return $Path }
        }
    }

    # 1) Always do per-user disable (no admin required)
    try {
        $kUser = Convert-ToRegistryProviderPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost'
        New-Item -Path $kUser -Force | Out-Null

        # Disable SmartScreen for Microsoft Store apps
        New-ItemProperty -Path $kUser -Name 'EnableWebContentEvaluation' -PropertyType DWord -Value 0 -Force | Out-Null

        # Optional: allow override in UI (PreventOverride=0 means user can change it)
        New-ItemProperty -Path $kUser -Name 'PreventOverride' -PropertyType DWord -Value 0 -Force | Out-Null

        $valEnable   = (Get-ItemProperty -Path $kUser -Name EnableWebContentEvaluation -ErrorAction SilentlyContinue).EnableWebContentEvaluation
        $valOverride = (Get-ItemProperty -Path $kUser -Name PreventOverride          -ErrorAction SilentlyContinue).PreventOverride

        Write-Log -message ("Disable-SmartScreenStoreApps :: HKCU Store app SmartScreen disabled (EnableWebContentEvaluation={0}, PreventOverride={1})" -f $valEnable, $valOverride) -severity 'INFO'
    }
    catch {
        Write-Log -message ("Disable-SmartScreenStoreApps :: HKCU step failed (path='{0}'): {1}" -f $kUser, $_.Exception.Message) -severity 'WARN'
    }

    # 2) If elevated, also set machine-wide (optional; affects all users)
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
                   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {

            # Ensure HKLM: drive exists (rare edge-case; makes the function more robust)
            if (-not (Get-PSDrive -Name HKLM -ErrorAction SilentlyContinue)) {
                New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE | Out-Null
            }

            $kMachine = Convert-ToRegistryProviderPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'

            # Debug breadcrumbs in case something upstream mutates the path
            Write-Log -message ("Disable-SmartScreenStoreApps :: DEBUG kMachine='{0}'" -f $kMachine) -severity 'DEBUG'

            New-Item -Path $kMachine -Force | Out-Null
            New-ItemProperty -Path $kMachine -Name 'EnableWebContentEvaluation' -PropertyType DWord -Value 0 -Force | Out-Null

            $mValEnable = (Get-ItemProperty -Path $kMachine -Name EnableWebContentEvaluation -ErrorAction SilentlyContinue).EnableWebContentEvaluation
            Write-Log -message ("Disable-SmartScreenStoreApps :: HKLM Store app SmartScreen disabled (EnableWebContentEvaluation={0})" -f $mValEnable) -severity 'INFO'
        }
        else {
            Write-Log -message "Disable-SmartScreenStoreApps :: not elevated; skipping HKLM machine-wide setting" -severity 'DEBUG'
        }
    }
    catch {
        Write-Log -message ("Disable-SmartScreenStoreApps :: HKLM step failed (path='{0}'): {1}" -f $kMachine, $_.Exception.Message) -severity 'DEBUG'
    }

    Write-Log -message "Disable-SmartScreenStoreApps :: complete (recommend sign out/in or restart Store apps)" -severity 'INFO'
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

$worker_location = $null
try {
    $image_provisioner = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet' -Name 'image_provisioner' -ErrorAction Stop
} catch {
    Write-Log -message ("Unable to read HKLM:\SOFTWARE\Mozilla\ronin_puppet\image_provisioner: {0}" -f $_.Exception.Message) -severity 'ERROR'
    exit 1
}

if ($image_provisioner -match '(?i)mdc1') {
    $worker_location = 'MDC1 hardware'
} elseif ($image_provisioner -match '(?i)azure') {
    $worker_location = 'azure vm'
} else {
    Write-Log -message ("Location can't be determined (image_provisioner='{0}')" -f $image_provisioner) -severity 'ERROR'
    exit 1
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
            Disable-PerUserUwpServices
            Remove-OneDriveScheduledTasks
            Disable-OneDriveBackupPopup
            Remove-EdgeScheduledTasks
            ## Not currently functioning
            #Disable-SyncFromCloud
            #Disable-SmartScreenStoreApps
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
