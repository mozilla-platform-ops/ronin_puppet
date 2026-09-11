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
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information'; $eventId = 1; break }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host -Object $message -ForegroundColor $fc
    }
}

function Set-PXE {
    param ()
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $temp_dir = "$env:SystemDrive\temp\"
        New-Item -ItemType Directory -Force -Path $temp_dir -ErrorAction SilentlyContinue
        bcdedit /enum firmware > "$temp_dir\firmware.txt"
        $fwbootmgr = Select-String -Path "$temp_dir\firmware.txt" -Pattern "{fwbootmgr}"
        if (!$fwbootmgr) {
            Write-Log -message ('{0} :: Device is configured for Legacy Boot. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Exit 999
        }
        Try {
            $FullLine = ((Get-Content "$temp_dir\firmware.txt" | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop).Context.PreContext)[0]
            $GUID = '{' + $FullLine.Split('{')[1]
            bcdedit /set "{fwbootmgr}" bootsequence "$GUID"
            Write-Log -message ('{0} :: Device will PXE boot. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Restart-Computer -Force
            Exit
        }
        Catch {
            Write-Log -message ('{0} :: Unable to set next boot to PXE. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Exit 888
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Register-FailureAndMaybePXE {
    param (
        [string] $regName
    )

    $regPath = "HKLM:\SOFTWARE\Mozilla\Ronin\GW_check_failures"
    if (!(Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    $currentValue = 0
    try {
        $currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop).$regName
    } catch {
        $currentValue = 0
    }
    if ($currentValue -eq 1) {
        Write-Log -message "$regName failure occurred again. Initiating PXE boot." -severity 'ERROR'
        Set-PXE
        exit
    } else {
        Write-Log -message "$regName failure detected. Rebooting system (1st failure)." -severity 'ERROR'
        Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Force
        Restart-Computer -Force
        Exit
    }
}

$bootstrap_stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
If ($bootstrap_stage -ne 'complete') {
    Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Exit
}

# Uptime check — allow 15-minute grace period before enforcing logic
$lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$uptimeMinutes = (New-TimeSpan -Start $lastBoot -End (Get-Date)).TotalMinutes
if ($uptimeMinutes -lt 15) {
    Write-Log -message "System has only been up for $([math]::Round($uptimeMinutes, 1)) minutes. Skipping generic-worker check until 15-minute threshold is met." -severity 'DEBUG'
    exit
}

# RELOPS-2402: fleetbench runs a ~15-min CPU benchmark BEFORE worker-runner starts
# (maintainsystem-hw.ps1 :: Invoke-FleetbenchCheck). During that run generic-worker is
# intentionally not started yet and uptime can pass the 15-min grace above, which would
# otherwise trip this watchdog into a needless reboot/PXE. Skip while a fresh benchmark
# marker is present. Read at Machine scope so we get the value live from the registry, not
# the (possibly stale) process env block. The marker is the run's UTC start time; a marker
# older than the max expected run is treated as stale so a crashed/rebooted run mid-benchmark
# cannot silently disable this check forever.
$fleetbenchMarker = [Environment]::GetEnvironmentVariable('MOZ_FLEETBENCH_RUNNING', 'Machine')
if ($fleetbenchMarker) {
    $fleetbenchMaxRunMinutes = 30   # 900s benchmark + warmup/startup slack
    [datetimeoffset] $fleetbenchStarted = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse($fleetbenchMarker, [ref] $fleetbenchStarted)) {
        $fleetbenchRunMinutes = ([datetimeoffset]::UtcNow - $fleetbenchStarted).TotalMinutes
        if ($fleetbenchRunMinutes -ge 0 -and $fleetbenchRunMinutes -lt $fleetbenchMaxRunMinutes) {
            Write-Log -message "Fleetbench benchmark in progress (started $($fleetbenchStarted.UtcDateTime.ToString('o')), $([math]::Round($fleetbenchRunMinutes, 1)) min ago). Skipping generic-worker check until it completes." -severity 'DEBUG'
            exit
        }
        Write-Log -message "Fleetbench marker present but stale ($([math]::Round($fleetbenchRunMinutes, 1)) min old, max $fleetbenchMaxRunMinutes). Ignoring and continuing generic-worker check." -severity 'WARN'
    }
    else {
        Write-Log -message "Fleetbench marker present but unparseable ('$fleetbenchMarker'). Ignoring and continuing generic-worker check." -severity 'WARN'
    }
}

# Var set by the maintain system script
# Check gw_initiated env var
if ($env:gw_initiated -ne 'true') {
    Write-Log -message "Environment variable gw_initiated is not true." -severity 'WARN'
    Register-FailureAndMaybePXE -regName 'gw_initiated_failed'
}

# Check for generic-worker process
# Write-Log -message "Checking for 'generic-worker' process..." -severity 'DEBUG'
$process = Get-Process -Name "generic-worker" -ErrorAction SilentlyContinue
if (-not $process) {
    Write-Log -message "generic-worker has not started." -severity 'WARN'
    Register-FailureAndMaybePXE -regName 'process_failed'
}

# Success path – clear failure flags
Write-Log -message "Generic-worker process is up and running." -severity 'DEBUG'
$regPath = "HKLM:\SOFTWARE\Mozilla\Ronin\GW_check_failures"
$failKeys = @('gw_initiated_failed', 'process_failed')
foreach ($key in $failKeys) {
    if (Test-Path $regPath) {
        try {
            if ((Get-ItemProperty -Path $regPath -Name $key -ErrorAction Stop).$key -eq 1) {
                Write-Log -message "Clearing $key failure flag." -severity 'DEBUG'
                Remove-ItemProperty -Path $regPath -Name $key -Force
            }
        } catch {}
    }
}
