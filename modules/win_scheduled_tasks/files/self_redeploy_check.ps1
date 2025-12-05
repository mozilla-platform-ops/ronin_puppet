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
function CompareConfig {
    param (
        [string]$yaml_url = "https://raw.githubusercontent.com/mozilla-platform-ops/worker-images/refs/heads/main/provisioners/windows/MDC1Windows/pools.yml",
        [string]$PAT
    )

    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }

    process {
        $yaml = $null
        $SETPXE = $false
        $yamlHash = $null
        $IPAddress = $null

        # -------------------------------
        # Resolve IP
        # -------------------------------
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
                Write-Log -message "Failed to get IP address" -severity 'ERROR'
            }
        }

        if ($IPAddress) {
            Write-Log -message "IP Address: $IPAddress" -severity 'INFO'
        }
        else {
            Write-Log -message "No IP Address could be determined." -severity 'ERROR'
            return
        }

        # -------------------------------
        # Reverse DNS
        # -------------------------------
        try {
            $ResolvedName = (Resolve-DnsName -Name $IPAddress -Server "10.48.75.120").NameHost
        }
        catch {
            Write-Log -message "DNS resolution failed." -severity 'ERROR'
            return
        }

        Write-Log -message "Resolved Name: $ResolvedName" -severity 'INFO'

        $index = $ResolvedName.IndexOf('.')
        if ($index -lt 0) {
            Write-Log -message "Invalid hostname format." -severity 'ERROR'
            return
        }

        $worker_node_name = $ResolvedName.Substring(0, $index)
        Write-Log -message "Host name set to: $worker_node_name" -severity 'INFO'

        # -------------------------------
        # Registry Values
        # -------------------------------
        $localHash = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).GITHASH
        $localPool = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).worker_pool_id

        # -------------------------------
        # Load YAML with retry
        # -------------------------------
        $maxRetries = 5
        $retryDelay = 10
        $attempt = 0
        $success = $false

        while ($attempt -lt $maxRetries -and -not $success) {
            try {
                $Headers = @{
                    Accept                 = "application/vnd.github+json"
                    Authorization          = "Bearer $($PAT)"
                    "X-GitHub-Api-Version" = "2022-11-28"
                }
                $response = Invoke-WebRequest -Uri $yaml_url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop -Headers $Headers
                $yaml = $response.Content | ConvertFrom-Yaml

                if ($yaml) {
                    $success = $true
                }
                else {
                    throw "YAML content is empty"
                }
            }
            catch {
                Write-Log -message "Attempt $($attempt + 1): Failed to fetch YAML - $_" -severity 'WARN'
                Start-Sleep -Seconds $retryDelay
                $attempt++
            }
        }

        if (-not $success) {
            Write-Log -message "YAML could not be loaded after $maxRetries attempts." -severity 'ERROR'
            $SETPXE = $true
        }

        # -------------------------------
        # Find pool entry
        # -------------------------------
        $found = $false
        if ($yaml) {
            foreach ($pool in $yaml.pools) {
                foreach ($node in $pool.nodes) {
                    if ($node -eq $worker_node_name) {
                        $WorkerPool = $pool.name
                        $yamlHash = $pool.hash
                        $yamlImageName = $pool.image
                        $yamlImageDir = "D:\" + $yamlImageName
                        $found = $true
                        break
                    }
                }
                if ($found) { break }
            }
        }

        if (-not $found) {
            Write-Log -message "Node name not found in YAML!!" -severity 'ERROR'
            $SETPXE = $true
        }

        Write-Log -message "=== Configuration Comparison ===" -severity 'INFO'

        # -------------------------------
        # Compare Worker Pool
        # -------------------------------
        if ($localPool -eq $WorkerPool) {
            Write-Log -message "Worker Pool Match: $WorkerPool" -severity 'INFO'
        }
        else {
            Write-Log -message "Worker Pool MISMATCH!" -severity 'ERROR'
            $SETPXE = $true
        }

        # -------------------------------
        # Compare Git Hash, including empty or null yamlHash
        # -------------------------------
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

        # -------------------------------
        # Check Image Directory
        # -------------------------------
        if (!(Test-Path $yamlImageDir)) {
            Write-Log -message "Image Directory MISMATCH! YAML: $yamlImageDir NOT FOUND" -severity 'ERROR'
            $SETPXE = $true
        }

        # ====================================================================================
        # NEW LOGIC: Evaluate worker-status.json BEFORE reboot or PXE trigger
        # ====================================================================================
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
                Restart-Computer -Force
                return
            }

            # -------------------------------
            # Parse worker-status.json
            # -------------------------------
            try {
                $json = Get-Content $workerStatus -Raw | ConvertFrom-Json
            }
            catch {
                Write-Log -message "worker-status.json is unreadable. Rebooting now!" -severity 'ERROR'
                Restart-Computer -Force
                return
            }

            if (($json.currentTaskIds).Count -eq 0) {
                Write-Log -message "No active tasks. Rebooting now!" -severity 'WARN'
                Restart-Computer -Force
                return
            }
            else {
                $task = $json.currentTaskIds[0]
                Write-Log -message "Task $task is active. Reboot will occur on next boot." -severity 'INFO'
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
