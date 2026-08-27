# win_enable_appxsvc.ps1
# AppXSvc management ONLY (undo the baked hard-disable + verification)
#
# Mirror image of win_disable_appxsvc.ps1, for the ref / ref-alpha pools. The golden
# install.wim is baked with AppXSvc disabled, so this has to actively undo BOTH halves of
# that: the \Hardening\Hard-Disable-AppXSvc startup task (removed first, otherwise it
# re-disables the service on the next boot) and the service's own Start value.
#
# Why it matters: the HEVC/AV1/VP9/WebMedia extensions are PROVISIONED into the image at
# bake time (DISM-level, needs no AppXSvc), but the per-user REGISTRATION that happens when
# a task_* user first logs on does need the service. Without it Firefox falls back to
# 'ffvpx video decoder (RDD remote)' and mochitest-media-mda-gpu fails.

$Script:Version = "win_enable_appxsvc.ps1 2026-08-20 svc-only v1"
Write-Output "enable_appxsvc :: starting ($Script:Version)"

function Write-Log {
    param (
        [string] $message,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string] $severity = 'INFO',
        [string] $source   = 'BootStrap',
        [string] $logName  = 'Application'
    )

    $entryType = 'Information'
    $eventId   = 1

    switch ($severity) {
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information';  $eventId = 1; break }
    }

    try { Write-Output $message } catch { }

    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or
            !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source -ErrorAction SilentlyContinue | Out-Null
        }
    } catch { }

    try {
        Write-EventLog -LogName $logName -Source $source `
            -EntryType $entryType -Category 0 -EventID $eventId `
            -Message $message -ErrorAction SilentlyContinue
    } catch { }
}

$ErrorActionPreference = 'Continue'

$svcName    = 'AppXSvc'
$svcKeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\AppXSvc'
$taskName   = 'Hard-Disable-AppXSvc'
$taskPath   = '\Hardening\'

function Remove-AppXSvcHardeningTask {
    [CmdletBinding()]
    param()

    Import-Module ScheduledTasks -ErrorAction SilentlyContinue | Out-Null

    # MUST go before the service is re-enabled: it runs at startup and would otherwise put
    # Start back to 4 on the next boot, silently undoing this whole class.
    $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($task) {
        try {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
            Write-Log -message ('Remove-AppXSvcHardeningTask :: removed {0}{1}' -f $taskPath, $taskName) -severity 'DEBUG'
        }
        catch {
            Write-Log -message ('Remove-AppXSvcHardeningTask :: FAILED to remove {0}{1}: {2}' -f $taskPath, $taskName, $_.Exception.Message) -severity 'ERROR'
        }
    }
    else {
        Write-Log -message ('Remove-AppXSvcHardeningTask :: {0}{1} not present' -f $taskPath, $taskName) -severity 'DEBUG'
    }

    # The hardening payload the task ran; harmless once the task is gone, but leaving it
    # invites someone re-registering it by hand.
    $hardeningFile = 'C:\ProgramData\AppXLock\Disable-AppXSvc.ps1'
    if (Test-Path $hardeningFile) {
        Remove-Item -Path $hardeningFile -Force -ErrorAction SilentlyContinue
        Write-Log -message ('Remove-AppXSvcHardeningTask :: removed {0}' -f $hardeningFile) -severity 'DEBUG'
    }
}

function Enable-AppXSvcCore {
    [CmdletBinding()]
    param()

    # Manual, NOT Automatic: AppXSvc is demand-started. Manual is what a stock Windows 11
    # install ships and what the working reference nodes (MDT image) run.
    if (Test-Path $svcKeyPath) {
        New-ItemProperty -Path $svcKeyPath -Name Start -Value 3 -PropertyType DWord -Force | Out-Null
    }

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        try { Set-Service -Name $svcName -StartupType Manual -ErrorAction Stop }
        catch { Write-Log -message ('Enable-AppXSvcCore :: Set-Service failed: {0}' -f $_.Exception.Message) -severity 'WARN' }
    }

    # Best-effort: do NOT leak sc.exe exit code
    try { & sc.exe config $svcName start= demand | Out-Null } catch { } finally { $global:LASTEXITCODE = 0 }
}

function Test-AppXSvcEnabled {
    [CmdletBinding()]
    param()

    $regStart = $null
    try { $regStart = (Get-ItemProperty -Path $svcKeyPath -Name Start -ErrorAction SilentlyContinue).Start } catch { }
    if ($regStart -eq 4) { return $false }

    try {
        $svcCim = Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
        if ($svcCim -and $svcCim.StartMode -eq 'Disabled') { return $false }
    } catch { }

    if (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue) { return $false }

    return $true
}

# --- Main ---------------------------------------------------------------
try {
    Write-Log -message 'enable_appxsvc :: begin' -severity 'DEBUG'

    Write-Log -message 'enable_appxsvc :: Remove-AppXSvcHardeningTask' -severity 'DEBUG'
    Remove-AppXSvcHardeningTask

    Write-Log -message 'enable_appxsvc :: Enable-AppXSvcCore' -severity 'DEBUG'
    Enable-AppXSvcCore

    # Verify with retries
    $max = 10
    for ($i = 1; $i -le $max; $i++) {
        if (Test-AppXSvcEnabled) { break }
        Write-Log -message ("enable_appxsvc :: waiting for AppXSvc to enable ({0}/{1})" -f $i, $max) -severity 'DEBUG'
        Start-Sleep -Seconds 2
        Remove-AppXSvcHardeningTask
        Enable-AppXSvcCore
    }

    if (-not (Test-AppXSvcEnabled)) {
        Write-Log -message 'enable_appxsvc :: AppXSvc is NOT enabled' -severity 'ERROR'
        exit 2
    }

    Write-Log -message 'enable_appxsvc :: complete (AppXSvc set to Manual, hardening task removed)' -severity 'DEBUG'
    exit 0
}
catch {
    $msg = "enable_appxsvc :: FATAL: $($_.Exception.ToString())"
    try { Write-Output $msg } catch { }
    Write-Log -message $msg -severity 'ERROR'
    exit 1
}
