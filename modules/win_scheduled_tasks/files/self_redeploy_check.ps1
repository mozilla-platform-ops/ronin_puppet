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

# -------------------------------------------------------------------
# Persistent PXE Pending Flag
# -------------------------------------------------------------------
function Set-PXEPendingFlag {
    param([switch]$Clear)

    $regPath = "HKLM:\SOFTWARE\Mozilla\PXE"
    $name    = "PendingPXE"

    if ($Clear) {
        if (Test-Path $regPath) {
            Remove-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue
        }
        return
    }

    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    New-ItemProperty -Path $regPath -Name $name -Value "1" -PropertyType String -Force | Out-Null
}

function Get-PXEPendingFlag {
    $regPath = "HKLM:\SOFTWARE\Mozilla\PXE"
    $name    = "PendingPXE"

    if (Test-Path "$regPath\$name") { return $true }
    return $false
}

function CompareConfig {
    param (
        [string]$yaml_url = "https://raw.githubusercontent.com/mozilla-platform-ops/worker-images/refs/heads/main/provisioners/windows/MDC1Windows/pools.yml",
        [string]$PAT
    )

    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'

        # Detect previous deferral due to active task
        if (Get-PXEPendingFlag) {
            Write-Log -message "PXE/Reboot pending task completion from previous run." -severity 'INFO'
        }
    }

    process {
        $yaml = $null
        $SETPXE = $false
        $yamlHash = $null

        # -------------------------------
        # Hostname via local variable (no IP/DNS lookup)
        # -------------------------------
        $worker_node_name = ($env:COMPUTERNAME).Trim().ToLower()
        if ([string]::IsNullOrWhiteSpace($worker_node_name)) {
            Write-Log -message ('{0} :: COMPUTERNAME is empty; cannot continue.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Set-PXEPendingFlag -Clear
            Restart-Computer -Force
            return
        }

        Write-Log -message "Host name set to: $worker_node_name" -severity 'INFO'

        # -------------------------------
        # Local ronin puppet values
        # -------------------------------
        $localHash = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).GITHASH
        $localPool = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).worker_pool_id

        # -------------------------------
        # PAT for YAML download
        # -------------------------------
        $patFile = "D:\Secrets\pat.txt"
        if (-not (Test-Path $patFile)) {
            Write-Log -message ('{0} :: PAT file missing: {1}' -f $MyInvocation.MyCommand.Name, $patFile) -severity 'ERROR'
            Set-PXE
            Set-PXEPendingFlag -Clear
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        $tempYamlPath = "$env:TEMP\pools.yml"
        $PAT = Get-Content $patFile -ErrorAction Stop

        $splat = @{
            Url  = $yaml_url
            Path = $tempYamlPath
            PAT  = $PAT
        }

        if (-not (Invoke-DownloadWithRetryGithub @splat)) {
            Write-Log -message ('{0} :: YAML download failed after retries. PXE rebooting.' -f $MyInvocation.MyCommand.Name) -severity 'ERROR'
            Set-PXE
            Set-PXEPendingFlag -Clear
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        try {
            $yaml = Get-Content $tempYamlPath -Raw | ConvertFrom-Yaml
        }
        catch {
            Write-Log -message ('{0} :: YAML parsing failed: {1}' -f $MyInvocation.MyCommand.Name, $_) -severity 'ERROR'
            Set-PXE
            Set-PXEPendingFlag -Clear
            Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
            Start-Sleep -Seconds 30
            Restart-Computer -Force
            return
        }

        # -------------------------------
        # Lookup this worker in pools.yml
        # -------------------------------
        $found = $false
        if ($yaml) {
            foreach ($pool in $yaml.pools) {
                $nodes = @($pool.nodes | ForEach-Object { "$_".Trim().ToLower() })
                if ($nodes -contains $worker_node_name) {
                    $WorkerPool    = $pool.name
                    $yamlHash      = $pool.hash
                    $yamlImageName = $pool.image
                    $yamlImageDir  = "D:\" + $yamlImageName
                    $found = $true
                    break
                }
            }
        }

        if (-not $found) {
            Write-Log -message ('Node name "{0}" not found in YAML!!' -f $worker_node_name) -severity 'ERROR'
            # $SETPXE = $true
        }

        Write-Log -message "=== Configuration Comparison ===" -severity 'INFO'

        if ($localPool -eq $WorkerPool) {
            Write-Log -message "Worker Pool Match: $WorkerPool" -severity 'INFO'
        }
        else {
            Write-Log -message "Worker Pool MISMATCH!" -severity 'ERROR'
            #$SETPXE = $true
        }

        if ([string]::IsNullOrWhiteSpace($yamlHash)) {
            Write-Log -message "YAML hash is missing or invalid. Treating as mismatch." -severity 'ERROR'
            $SETPXE = $true
        }
        elseif ($localHash -ne $yamlHash) {
            Write-Log -message "Git Hash MISMATCH!" -severity 'ERROR'
            Write-Log -message "Local: $localHash" -severity 'WARN'
            Write-Log -message "YAML : $yamlHash" -severity 'WARN'
            $SETPXE = $true
        }
        else {
            Write-Log -message "Git Hash Match: $yamlHash" -severity 'INFO'
        }

        if (!(Test-Path $yamlImageDir)) {
            Write-Log -message "Image Directory MISMATCH! YAML: $yamlImageDir NOT FOUND" -severity 'ERROR'
            $SETPXE = $true
        }

        if ($SETPXE) {

            Write-Log -message "Configuration mismatch detected. Evaluating worker-status.json..." -severity 'WARN'

            $searchPaths = @(
                "C:\WINDOWS\SystemTemp",
                $env:TMP,
                $env:TEMP,
                $env:USERPROFILE
            )

            $workerStatus = $null
            foreach ($path in $searchPaths) {
                if ($null -ne $path) {
                    $candidate = Join-Path $path "worker-status.json"
                    if (Test-Path $candidate) {
                        $workerStatus = $candidate
                        break
                    }
                }
            }

            if (-not $workerStatus) {
                Write-Log -message "worker-status.json not found. Rebooting now!" -severity 'ERROR'
                Set-PXEPendingFlag -Clear
                Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
                Start-Sleep -Seconds 30
                Restart-Computer -Force
                return
            }

            try {
                $json = Get-Content $workerStatus -Raw | ConvertFrom-Json
            }
            catch {
                Write-Log -message "worker-status.json is unreadable. Rebooting now!" -severity 'ERROR'
                Set-PXEPendingFlag -Clear
                Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
                Start-Sleep -Seconds 30
                Restart-Computer -Force
                return
            }

            if (($json.currentTaskIds).Count -eq 0) {
                Write-Log -message "No active tasks. Rebooting now!" -severity 'WARN'
                Set-PXEPendingFlag -Clear
                Write-Log -message ('{0} :: Sleeping 30s before reboot to allow logs to flush.' -f $MyInvocation.MyCommand.Name) -severity 'WARN'
                Start-Sleep -Seconds 30
                Restart-Computer -Force
                return
            }
            else {
                $task = $json.currentTaskIds[0]
                Write-Log -message "Task $task is active. PXE/Reboot deferred until task completion." -severity 'INFO'

                # Record pending reboot/PXE
                Set-PXEPendingFlag

                # Prepare PXE boot
                Set-PXE
                return
            }
        }

        Write-Log -message "SETPXE set to: $SETPXE" -severity 'DEBUG'
    }

    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

$bootstrap_stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
If ($bootstrap_stage -eq 'complete') {
    CompareConfig
} else {
    Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Exit-PSSession
}
