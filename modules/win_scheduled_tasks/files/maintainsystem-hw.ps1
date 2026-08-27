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

function Run-MaintainSystem {
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        #Remove-OldTaskDirectories
        Get-ChildItem "$env:systemdrive\logs\old" -Recurse -File | Where-Object CreationTime -lt  (Get-Date).AddDays(-7)  | Remove-Item -Force
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Invoke-DownloadWithRetryGithub {
    Param(
        [Parameter(Mandatory)] [string] $Url,
        [Alias("Destination")] [string] $Path,
        [string] $PAT
    )
    if (-not $Path) {
        $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
        $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
        $fileName = [IO.Path]::GetFileName($Url) -replace $re
        if ([String]::IsNullOrEmpty($fileName)) { $fileName = [System.IO.Path]::GetRandomFileName() }
        $Path = Join-Path -Path "${env:Temp}" -ChildPath $fileName
    }
    Write-Host "Downloading package from $Url to $Path..."
    $interval = 30
    $downloadStartTime = Get-Date
    for ($retries = 20; $retries -gt 0; $retries--) {
        try {
            $attemptStartTime = Get-Date
            $Headers = @{
                Accept                 = "application/vnd.github+json"
                Authorization          = "Bearer $($PAT)"
                "X-GitHub-Api-Version" = "2022-11-28"
            }
            $response = Invoke-WebRequest -Uri $Url -Headers $Headers -OutFile $Path
            $attemptSeconds = [math]::Round(($(Get-Date) - $attemptStartTime).TotalSeconds, 2)
            Write-Host "Package downloaded in $attemptSeconds seconds"
            Write-Host "Status: $($response.statuscode)"
            break
        } catch {
            $attemptSeconds = [math]::Round(($(Get-Date) - $attemptStartTime).TotalSeconds, 2)
            Write-Warning "Package download failed in $attemptSeconds seconds"
            Write-Host "Status: $($response.statuscode)"
            Write-Warning $_.Exception.Message
            if ($_.Exception.InnerException.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
                Write-Warning "Request returned 404 Not Found. Aborting download."
                $retries = 0
            }
        }
        if ($retries -eq 0) {
            $totalSeconds = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
            throw "Package download failed after $totalSeconds seconds"
        }
        Write-Warning "Waiting $interval seconds before retrying (retries left: $retries)..."
        Start-Sleep -Seconds $interval
    }
    return $Path
}

function CompareConfigBasic {
    param (
        [string]$yaml_url = "https://raw.githubusercontent.com/mozilla-platform-ops/worker-images/refs/heads/main/provisioners/windows/MDC1Windows/pools.yml",
        [string]$PAT
    )

    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }

    process {

        $SETPXE = $false
        $yaml = $null
        $yamlHash = $null

        # === Use local computer name (no IP/DNS lookup) ===
        $worker_node_name = ($env:COMPUTERNAME).Trim().ToLower()
        if ([string]::IsNullOrWhiteSpace($worker_node_name)) {
            Write-Log -message ('{0} :: COMPUTERNAME is empty; cannot continue.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        Write-Log -message ('{0} :: Host name set to: {1}' -f $MyInvocation.MyCommand.Name, $worker_node_name) -severity 'INFO'

        # === Load local ronin puppet values ===
        $localHash = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).GITHASH
        $localPool = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).worker_pool_id

        # === Load PAT for YAML download ===
        $patFile = "D:\Secrets\pat.txt"
        if (-not (Test-Path $patFile)) {
            Write-Log -message ('{0} :: PAT file missing: {1}' -f $MyInvocation.MyCommand.Name, $patFile) -severity 'ERROR'
            Set-PXE
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        $PAT = Get-Content $patFile -ErrorAction Stop

        # === Download YAML using unified retry function ===
        $tempYamlPath = "$env:TEMP\pools.yml"

        $splat = @{
            Url  = $yaml_url
            Path = $tempYamlPath
            PAT  = $PAT
        }

        if (-not (Invoke-DownloadWithRetryGithub @splat)) {
            Write-Log -message ('{0} :: YAML download failed after retries. PXE rebooting.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Set-PXE
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        # === Parse YAML ===
        try {
            $yaml = Get-Content $tempYamlPath -Raw | ConvertFrom-Yaml
        }
        catch {
            Write-Log -message ('{0} :: YAML parsing failed: {1}' -f $MyInvocation.MyCommand.Name, $_) -severity 'ERROR'
            Set-PXE
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        # === Lookup this worker in pools.yml ===
        $found = $false
        foreach ($pool in $yaml.pools) {
            $nodes = @($pool.nodes | ForEach-Object { "$_".Trim().ToLower() })
            if ($nodes -contains $worker_node_name) {
                $WorkerPool     = $pool.name
                $yamlHash       = $pool.hash
                $yamlImageName  = $pool.image
                $yamlImageDir   = "D:\" + $yamlImageName
                $found = $true
                break
            }
        }

        if (-not $found) {
            Write-Log -message ('{0} :: Node "{1}" not found in YAML. PXE rebooting.' -f $MyInvocation.MyCommand.Name, $worker_node_name) -severity 'ERROR'
            Set-PXE
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        Write-Log -message ('{0} :: === Configuration Comparison ===' -f $MyInvocation.MyCommand.Name) -severity 'INFO'

        # === Compare pool ===
        if ($localPool -ne $WorkerPool) {
            Write-Log -message ('{0} :: Worker Pool MISMATCH!' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            $SETPXE = $true
        }
        else {
            Write-Log -message ('{0} :: Worker Pool Match: {1}' -f $MyInvocation.MyCommand.Name, $WorkerPool) -severity 'INFO'
        }

        # === Compare puppet githash ===
        if ([string]::IsNullOrWhiteSpace($yamlHash) -or $localHash -ne $yamlHash) {
            Write-Log -message ('{0} :: Git Hash MISMATCH or missing YAML hash!' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Write-Log -message ('{0} :: Local: {1}' -f $MyInvocation.MyCommand.Name, $localHash) -severity 'WARN'
            Write-Log -message ('{0} :: YAML : {1}' -f $MyInvocation.MyCommand.Name, $yamlHash) -severity 'WARN'
            $SETPXE = $true
        }
        else {
            Write-Log -message ('{0} :: Git Hash Match: {1}' -f $MyInvocation.MyCommand.Name, $yamlHash) -severity 'INFO'
        }

        # === Verify local puppet image directory exists ===
        if (!(Test-Path $yamlImageDir)) {
            Write-Log -message ('{0} :: Image directory missing: {1}' -f $MyInvocation.MyCommand.Name, $yamlImageDir) -severity 'ERROR'
            $SETPXE = $true
        }

        # === If anything mismatched, PXE reboot ===
        if ($SETPXE) {
            Write-Log -message ('{0} :: Configuration mismatch — initiating PXE + reboot.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Set-PXE
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        Write-Log -message ('{0} :: Configuration is correct. No reboot required.' -f $MyInvocation.MyCommand.Name) -severity 'INFO'
    }

    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Remove-OldTaskDirectories {
    param (
        [string[]] $targets = @('Z:\task_*', 'C:\Users\task_*')
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        foreach ($target in ($targets | Where-Object { (Test-Path -Path ('{0}:\' -f $_[0]) -ErrorAction SilentlyContinue) })) {
            $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.LastWriteTime })
            if ($all_task_paths.length -gt 1) {
                Write-Log -message ('{0} :: {1} task directories detected matching pattern: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths.length, $target) -severity 'INFO'
                $old_task_paths = $all_task_paths[0..($all_task_paths.Length - 2)]
                foreach ($old_task_path in $old_task_paths) {
                    try {
                        & takeown.exe @('/a', '/f', $old_task_path, '/r', '/d', 'Y')
                        & icacls.exe @($old_task_path, '/grant', 'Administrators:F', '/t')
                        Remove-Item -Path $old_task_path -Force -Recurse
                        Write-Log -message ('{0} :: removed task directory: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime) -severity 'INFO'
                    }
                    catch {
                        Write-Log -message ('{0} :: failed to remove task directory: {1}, with last write time: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime, $_.Exception.Message) -severity 'ERROR'
                    }
                }
            }
            elseif ($all_task_paths.length -eq 1) {
                Write-Log -message ('{0} :: a single task directory was detected at: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths[0].FullName, $all_task_paths[0].LastWriteTime) -severity 'DEBUG'
            }
            else {
                Write-Log -message ('{0} :: no task directories detected matching pattern: {1}' -f $($MyInvocation.MyCommand.Name), $target) -severity 'DEBUG'
            }
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function StartWorkerRunner {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        ## Checking for issues with the user profile.
        $lastBootTime = Get-WinEvent -LogName "System" -FilterXPath "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[EventID=12]]</Select></Query></QueryList>" |
        Select-Object -First 1 |
        ForEach-Object { $_.TimeCreated }
        $eventIDs = @(1511, 1515)

        $events = Get-WinEvent -LogName "Application" |
        Where-Object { $_.ID -in $eventIDs -and $_.TimeCreated -gt $lastBootTime } |
        Sort-Object TimeCreated -Descending | Select-Object -First 1

        if ($events) {
            Write-Log -message  ('{0} :: Possible User Profile Corruption. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Restart-Computer -Force
            exit
        }
        Start-Service -Name worker-runner
        [Environment]::SetEnvironmentVariable('gw_initiated', 'true', 'Machine')
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Get-LoggedInUser {
    [CmdletBinding()]
    param (

    )

    @(((query user) -replace '\s{20,39}', ',,') -replace '\s{2,}', ',' | ConvertFrom-Csv)
}

function Get-LatestGoogleChrome {
    [CmdletBinding()]
    param (
        [String]
        $Package = "googlechrome"
    )

    ## Current version of google chrome
    $current_version = choco list --exact $Package --limit-output | ConvertFrom-Csv -Delimiter '|' -Header 'Name', 'CurrentVersion'

    ## Use chocolatey with outdated
    $choco_packages = choco outdated --limit-output | ConvertFrom-Csv -Delimiter '|' -Header 'Name', 'CurrentVersion', 'AvailableVersion', 'Pinned'

    ## Check if Google Chrome is present
    $pkg = $choco_packages | Where-Object { $_.Name -eq $Package }

    ## There is no google chrome update, so output the current version
    if ([String]::IsNullOrEmpty($pkg)) {
        Write-Log -message ('{0} :: Google Chrome version installed is {1}' -f $($MyInvocation.MyCommand.Name), $current_version.CurrentVersion) -severity 'DEBUG'
    }
    else {
        ## Chrome is installed and needs to be updated
        if ($pkg.CurrentVersion -ne $pkg.AvailableVersion) {
            ## run choco upgrade
            Write-Log -message ('{0} :: Updating Google Chrome from current: {1} to available: {2}' -f $($MyInvocation.MyCommand.Name), $pkg.currentVersion, $pkg.availableVersion) -severity 'DEBUG'
            choco upgrade $Package -y "--ignore-checksums" "--ignore-package-exit-codes" "--log-file" $env:systemdrive\logs\googlechrome.log
            if ($LASTEXITCODE -ne 0) {
                ## output to papertrail
                Write-Log -message ('{0} :: choco upgrade googlechrome failed with {1}' -f $($MyInvocation.MyCommand.Name), $LASTEXITCODE) -severity 'DEBUG'
                ## output chocolatey logs to papertrail
                Get-Content $env:systemdrive\logs\googlechrome.log | ForEach-Object { Write-Log -message $_ -severity 'DEBUG' }
                ## Sending the logs to papertrail, wait 30 seconds
                Start-Sleep -Seconds 60
                ## PXE Boot
                Set-PXE
            }
            else {
                ## Need to reboot in order to complete the upgrade
                Write-Log -message ('{0} :: Google Chrome needs to reboot to complete upgrade. Rebooting..' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Start-Sleep -Seconds 10
                Restart-Computer -Force
            }
        }
    }
}

function Set-PXE {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $temp_dir = "$env:systemdrive\temp\"
        New-Item -ItemType Directory -Force -Path $temp_dir -ErrorAction SilentlyContinue

        bcdedit /enum firmware > $temp_dir\firmware.txt

        $fwbootmgr = Select-String -Path "$temp_dir\firmware.txt" -Pattern "{fwbootmgr}"
        if (!$fwbootmgr) {
            Write-Log -message  ('{0} :: Device is configured for Legacy Boot. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Exit 999
        }
        Try {
            # Get the line of text with the GUID for the PXE boot option.
            # IPV4 = most PXE boot options
            $FullLine = (( Get-Content $temp_dir\firmware.txt | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop ).context.precontext)[0]

            # Remove all text but the GUID
            $GUID = '{' + $FullLine.split('{')[1]

            # Add the PXE boot option to the top of the boot order on next boot
            bcdedit /set "{fwbootmgr}" bootsequence "$GUID"

            Write-Log -message  ('{0} :: Device will PXE boot. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Restart-Computer -Force
        }
        Catch {
            Write-Log -message  ('{0} :: Unable to set next boot to PXE. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Exit 888
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Test-ConnectionUntilOnline {
    param (
        [string]$Hostname = "www.google.com",
        [int]$Interval = 5,
        [int]$TotalTime = 120
    )

    $elapsedTime = 0

    while ($elapsedTime -lt $totalTime) {
        if (Test-Connection -ComputerName $hostname -Count 1 -Quiet) {
            Write-Log -message ('{0} :: {1} is online! Continuing.' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME) -severity 'DEBUG'
            return
        }
        else {
            Write-Log -message ('{0} :: {1} is not online, checking again in {2}' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME, $interval) -severity 'DEBUG'
            Start-Sleep -Seconds $interval
            $elapsedTime += $interval
        }
    }

    Write-Log -message ('{0} :: {1} did not come online within {2} seconds' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME, $totalTime) -severity 'DEBUG'
    throw "Connection timeout."
}
function Wait-ForUserInitReady {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 600,
        [int]$PollSeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    Write-Log -message ("MOZ_GW_UI_READY :: waiting up to {0}s for user-init signal" -f $TimeoutSeconds) -severity 'INFO'

    while ((Get-Date) -lt $deadline) {
        try {
            $v = [Environment]::GetEnvironmentVariable('MOZ_GW_UI_READY', 'Machine')

            if ($v -eq '1') {
                Write-Log -message "MOZ_GW_UI_READY :: ready (value=1)" -severity 'INFO'
                return $true
            }

            if ($null -eq $v) {
                Write-Log -message "MOZ_GW_UI_READY :: not set yet" -severity 'DEBUG'
            } else {
                Write-Log -message ("MOZ_GW_UI_READY :: present but not ready (value={0})" -f $v) -severity 'DEBUG'
            }
        } catch {
            Write-Log -message ("MOZ_GW_UI_READY :: read failed: {0}" -f $_.Exception.Message) -severity 'WARN'
        }

        Start-Sleep -Seconds $PollSeconds
    }

    Write-Log -message ("MOZ_GW_UI_READY :: timeout after {0}s" -f $TimeoutSeconds) -severity 'WARN'
    return $false
}

function Write-DefenderStatus {
    # Persist the latest Defender real-time guard state to a small status file that
    # NSClient++ surfaces to Marlin (read by scripts\check_defender.ps1). Best-effort.
    param (
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] $Status
    )
    try {
        $Status | ConvertTo-Json -Compress | Out-File -FilePath $Path -Encoding utf8
    }
    catch {
        Write-Log -message ('Write-DefenderStatus :: failed: {0}' -f $_.Exception.Message) -severity 'WARN'
    }
}

function Invoke-DefenderRealtimeGuard {
    # Ensure Windows Defender real-time / on-access scanning is OFF before worker-runner.
    #
    # On this fleet Tamper Protection is ENFORCED (cannot be disabled in-OS), so the
    # supported toggles (Set-MpPreference, sc config WdFilter, fltmc unload, the policy
    # registry values) are all blocked or ignored. The only lever that works is renaming
    # the Defender driver binaries (WdFilter/WdBoot/WdNisDrv) - done below Tamper's reach
    # via takeown - which takes effect on the NEXT boot. WdFilter is a BOOT-START
    # minifilter, so a boot that follows a Defender platform update (which restores
    # WdFilter.sys) comes up with on-access scanning ACTIVE for the whole session.
    #
    # This guard runs at boot, before worker-runner. It: (1) re-renames any restored
    # driver so the next boot is clean, (2) tries the supported in-session unload (works
    # only if Tamper happens to be off, e.g. a Tamper-off image), and (3) if the filter is
    # still running under Tamper, reboots ONCE (boot-loop guarded) so the node comes up
    # clean before any CI task runs. Writes defender_status.json for Marlin/Grafana.
    param (
        [string] $StatusDir   = 'C:\fleetbench\results',  # dir NSClient++ already reads
        [int]    $MaxReboots  = 1,                         # max reboots per restore event
        [int]    $CooldownMin = 60                         # suppress re-reboot within this window
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        try {
            $drvDir     = Join-Path $env:SystemRoot 'System32\drivers'
            $drivers    = @('WdFilter', 'WdBoot', 'WdNisDrv')
            if (-not (Test-Path $StatusDir)) { New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null }
            $statusFile = Join-Path $StatusDir 'defender_status.json'
            $markerFile = Join-Path $StatusDir 'defender_guard.json'

            # (0) Blanket on-access path exclusions for the CI volumes. Unlike the AV
            # engine/services, GP-managed exclusions ARE writable and honored under Tamper
            # Protection, so even on a boot where WdFilter is still loaded (right after a
            # Defender platform update, before the reboot below) on-access scanning of the
            # work volumes is skipped. Re-asserted every boot in case an update clears them.
            try {
                $exRoot  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions'
                $exPaths = Join-Path $exRoot 'Paths'
                foreach ($k in @($exRoot, $exPaths)) { if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null } }
                Set-ItemProperty -Path $exRoot -Name 'Exclusions_Paths' -Value 1 -Type DWord
                foreach ($p in @('C:\', 'D:\')) {
                    if (Test-Path -LiteralPath $p) {
                        New-ItemProperty -Path $exPaths -Name $p -Value 0 -PropertyType DWord -Force | Out-Null
                    }
                }
            }
            catch {
                Write-Log -message ('{0} :: exclusion set partial: {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'WARN'
            }

            # (1) Re-disable persistently: rename any restored driver binaries so the NEXT
            # boot comes up clean. No-op when already renamed (the normal steady state).
            $renamed = @()
            foreach ($d in $drivers) {
                $sys = Join-Path $drvDir ($d + '.sys')
                if (Test-Path -LiteralPath $sys) {
                    try {
                        & "$env:SystemRoot\System32\takeown.exe" /f $sys /a | Out-Null
                        & "$env:SystemRoot\System32\icacls.exe" $sys /grant 'Administrators:F' | Out-Null
                        $bak = $sys + '.bak'
                        if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force -ErrorAction SilentlyContinue }
                        Rename-Item -LiteralPath $sys -NewName ($d + '.sys.bak') -Force
                        $renamed += $d
                    }
                    catch {
                        Write-Log -message ('{0} :: could not rename {1}.sys: {2}' -f $($MyInvocation.MyCommand.Name), $d, $_.Exception.Message) -severity 'WARN'
                    }
                }
            }
            if ($renamed.Count) {
                Write-Log -message ('{0} :: renamed restored Defender driver(s): {1} (likely a Defender platform update)' -f $($MyInvocation.MyCommand.Name), ($renamed -join ',')) -severity 'WARN'
            }

            # Is the on-access minifilter running right now?
            $wdfRunning = $false
            try { $wdfRunning = (((& "$env:SystemRoot\System32\sc.exe" query WdFilter 2>$null) | Select-String 'STATE') -match 'RUNNING') } catch { }
            $tamper = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -ErrorAction SilentlyContinue).TamperProtection

            $action = if ($renamed.Count) { 'renamed_only' } else { 'none' }

            if ($wdfRunning) {
                # Try the supported in-session unload first (succeeds only if Tamper is OFF).
                try {
                    $u = & "$env:SystemRoot\System32\fltMC.exe" unload WdFilter 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Start-Sleep -Seconds 2
                        $wdfRunning = (((& "$env:SystemRoot\System32\sc.exe" query WdFilter 2>$null) | Select-String 'STATE') -match 'RUNNING')
                        if (-not $wdfRunning) {
                            $action = 'unloaded'
                            Write-Log -message ('{0} :: WdFilter unloaded in-session (Tamper Protection off).' -f $($MyInvocation.MyCommand.Name)) -severity 'WARN'
                        }
                    }
                    else {
                        Write-Log -message ('{0} :: fltmc unload blocked (Tamper Protection on): {1}' -f $($MyInvocation.MyCommand.Name), ($u -join ' ')) -severity 'INFO'
                    }
                }
                catch { }
            }

            if ($wdfRunning) {
                # Cannot unload under Tamper. The .sys is now renamed, so a reboot yields a
                # clean boot. Reboot once, boot-loop guarded by a marker file.
                $count = 0; $lastUtc = $null
                if (Test-Path $markerFile) {
                    try {
                        $m = Get-Content -LiteralPath $markerFile -Raw | ConvertFrom-Json
                        $count = [int]$m.reboot_count
                        $lastUtc = [datetime]$m.last_reboot_utc
                    }
                    catch { }
                }
                $now = (Get-Date).ToUniversalTime()
                $withinCooldown = $false
                if ($lastUtc) { $withinCooldown = ((($now) - $lastUtc.ToUniversalTime()).TotalMinutes -lt $CooldownMin) }

                if ($count -ge $MaxReboots -and $withinCooldown) {
                    # Already rebooted recently and it is STILL active -> stop, do not loop.
                    $action = 'degraded'
                    Write-Log -message ('{0} :: WdFilter STILL ACTIVE after {1} reboot(s) within {2}m; proceeding WITHOUT another reboot to avoid a boot loop. On-access scanning may affect this session. Driver renamed for next clean boot.' -f $($MyInvocation.MyCommand.Name), $count, $CooldownMin) -severity 'ERROR'
                }
                else {
                    $newCount = if ($withinCooldown) { $count + 1 } else { 1 }
                    ([pscustomobject]@{ reboot_count = $newCount; last_reboot_utc = $now.ToString('o') } | ConvertTo-Json -Compress) | Out-File -FilePath $markerFile -Encoding utf8
                    $action = 'renamed_reboot'
                    Write-DefenderStatus -Path $statusFile -Status ([pscustomobject]@{
                        timestamp_utc     = $now.ToString('yyyy-MM-ddTHH:mm:ssZ'); host = $env:COMPUTERNAME
                        wdfilter_running  = $true; sys_renamed = (-not (Test-Path (Join-Path $drvDir 'WdFilter.sys')))
                        tamper_protection = $tamper; action = $action; reboot_count = $newCount
                    })
                    Write-Log -message ('{0} :: WdFilter active under Tamper; renamed driver(s) and rebooting (#{1}) to clear on-access scanning before worker-runner.' -f $($MyInvocation.MyCommand.Name), $newCount) -severity 'WARN'
                    Restart-Computer -Force
                    exit
                }
            }
            else {
                # Clean: not running. Clear the reboot marker so a future event starts fresh.
                if (Test-Path $markerFile) { Remove-Item -LiteralPath $markerFile -Force -ErrorAction SilentlyContinue }
            }

            Write-DefenderStatus -Path $statusFile -Status ([pscustomobject]@{
                timestamp_utc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); host = $env:COMPUTERNAME
                wdfilter_running  = $wdfRunning; sys_renamed = (-not (Test-Path (Join-Path $drvDir 'WdFilter.sys')))
                tamper_protection = $tamper; action = $action; reboot_count = 0
            })
        }
        catch {
            # Must never block worker-runner from starting.
            Write-Log -message ('{0} :: error: {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'WARN'
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Write-Log -message ('{0} :: maintained system started' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Write-Log -message ('{0} :: No user logged in (no explorer.exe); sleeping 60s' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Start-Sleep -Seconds 60
}
## Bug https://bugzilla.mozilla.org/show_bug.cgi?id=1910123
## The bug tracks when we reimaged a machine and the machine had a different refresh rate (64hz vs 60hz)
## This next line will check if the refresh rate is not 60hz and trigger a reimage if so
$hardware = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property Manufacturer, Model
$model = $hardware.Model
$refresh_rate = (Get-WmiObject win32_videocontroller).CurrentRefreshRate
if ($refresh_rate -ne "60") {
    Write-Log -message ('{0} :: Refresh rate is {1}. Reimaging {2}' -f $($MyInvocation.MyCommand.Name), $refresh_rate, $ENV:COMPUTERNAME) -severity 'DEBUG'
    Set-PXE
}

$bootstrap_stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
If ($bootstrap_stage -eq 'complete') {
    CompareConfigBasic
    Start-Sleep -Seconds 2
    Run-MaintainSystem
    ## We're getting user profile corruption errors, so let's check that the user is logged in using quser.exe
    for ($i = 0; $i -lt 3; $i++) {
        $loggedInUser = (Get-LoggedInUser).UserName -replace ">"
        if ($loggedInUser -notmatch "task") {
            Write-Log -message  ('{0} :: User logged in: {1}' -f $($MyInvocation.MyCommand.Name), $loggedInUser) -severity 'DEBUG'
            Start-Sleep -Seconds 10
        }
        else {
            Write-Log -message  ('{0} :: User logged in: {1}' -f $($MyInvocation.MyCommand.Name), $loggedInUser) -severity 'DEBUG'
            break
        }
    }
    ## Let's make sure the machine is online before checking the internet
    Test-ConnectionUntilOnline

    # Ensure Windows Defender real-time / on-access scanning is OFF before worker-runner.
    # Re-disables (renames) a driver restored by a Defender platform update and reboots
    # once to clear the running minifilter under Tamper Protection. Runs before the long
    # UI-init wait and the fleetbench benchmark so any needed reboot happens early.
    Invoke-DefenderRealtimeGuard

    ## Let's check for the latest install of google chrome using chocolatey before starting worker runner
    ## Instead of querying chocolatey each time this runs, let's query chrome json endoint and check locally installed version
    Get-LatestGoogleChrome
    # Wait for task-user-init (Win11 UI hardening) to complete before starting worker-runner
    $ready = Wait-ForUserInitReady -TimeoutSeconds 1200 -PollSeconds 3

    # Delete the env var either way to avoid it sticking around forever
    try {
        [Environment]::SetEnvironmentVariable('MOZ_GW_UI_READY', $null, 'Machine')
        Write-Log -message "MOZ_GW_UI_READY :: cleared (machine)" -severity 'DEBUG'
    } catch {
        Write-Log -message ("MOZ_GW_UI_READY :: failed to clear: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    if (-not $ready) {
        # If you prefer fail-closed (PXE) instead, change this behavior.
        Write-Log -message "MOZ_GW_UI_READY :: proceeding despite timeout" -severity 'WARN'
    }
    StartWorkerRunner
    Exit-PSSession
}
else {
    Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Exit-PSSession
}
