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
        $IPAddress = $null

        # === Retrieve IP address ===
        $Ethernet = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.Name -match "ethernet" }

        try {
            $IPAddress = ($Ethernet.GetIPProperties().UnicastAddresses |
                Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_.Address.IPAddressToString -ne "127.0.0.1" } |
                Select-Object -First 1 -ExpandProperty Address).IPAddressToString
        }
        catch {
            try {
                $NetshOutput = netsh interface ip show addresses
                $IPAddress = ($NetshOutput -match "IP Address" | ForEach-Object {
                        if ($_ -notmatch "127.0.0.1") { $_ -replace ".*?:\s*", "" }
                    })[0]
            }
            catch {
                Write-Log -message ('{0} :: Failed to get IP address' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            }
        }

        if (-not $IPAddress) {
            Write-Log -message ('{0} :: No IP Address could be determined.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Restart-Computer -Force
            return
        }

        Write-Log -message ('{0} :: IP Address: {1}' -f $MyInvocation.MyCommand.Name, $IPAddress) -severity 'INFO'


        # === Resolve DNS to get worker name ===
        try {
            $ResolvedName = (Resolve-DnsName -Name $IPAddress -Server "10.48.75.120").NameHost
        }
        catch {
            Write-Log -message ('{0} :: DNS resolution failed' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Restart-Computer -Force
            return
        }

        Write-Log -message ('{0} :: Resolved Name: {1}' -f $MyInvocation.MyCommand.Name, $ResolvedName) -severity 'INFO'

        $index = $ResolvedName.IndexOf('.')
        if ($index -lt 0) {
            Write-Log -message ('{0} :: Invalid hostname format.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Restart-Computer -Force
            return
        }

        $worker_node_name = $ResolvedName.Substring(0, $index)
        Write-Log -message ('{0} :: Host name set to: {1}' -f $MyInvocation.MyCommand.Name, $worker_node_name) -severity 'INFO'


        # === Load local ronin puppet values ===
        $localHash = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).GITHASH
        $localPool = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).worker_pool_id


        # === Load PAT for YAML download ===
        $patFile = "D:\Secrets\pat.txt"
        if (-not (Test-Path $patFile)) {
            Write-Log -message ('{0} :: PAT file missing: {1}' -f $MyInvocation.MyCommand.Name, $patFile) -severity 'ERROR'
            Set-PXE
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
            Restart-Computer -Force
            return
        }


        # === Lookup this worker in pools.yml ===
        $found = $false
        foreach ($pool in $yaml.pools) {
            if ($pool.nodes -contains $worker_node_name) {
                $WorkerPool     = $pool.name
                $yamlHash       = $pool.hash
                $yamlImageName  = $pool.image
                $yamlImageDir   = "D:\" + $yamlImageName
                $found = $true
                break
            }
        }

        if (-not $found) {
            Write-Log -message ('{0} :: Node not found in YAML. PXE rebooting.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Set-PXE
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
    Disable-PerUserUwpServices
    Remove-OneDriveScheduledTasks

    ## Let's make sure the machine is online before checking the internet
    Test-ConnectionUntilOnline

    ## Let's check for the latest install of google chrome using chocolatey before starting worker runner
    ## Instead of querying chocolatey each time this runs, let's query chrome json endoint and check locally installed version
    Get-LatestGoogleChrome

    StartWorkerRunner
    Exit-PSSession
}
else {
    Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Exit-PSSession
}
