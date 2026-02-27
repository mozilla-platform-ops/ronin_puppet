# win_disable_appxsvc.ps1
# AppXSvc management ONLY (disable + scheduled task hardening + verification)

$Script:Version = "win_disable_appxsvc.ps1 2026-02-20 svc-only v1"
Write-Output "disable_appxsvc :: starting ($Script:Version)"

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

function Disable-AppXSvcCore {
    [CmdletBinding()]
    param()

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
    }

    # Best-effort: do NOT leak sc.exe exit code
    try { & sc.exe config $svcName start= disabled | Out-Null } catch { } finally { $global:LASTEXITCODE = 0 }

    # Registry is source-of-truth
    if (Test-Path $svcKeyPath) {
        New-ItemProperty -Path $svcKeyPath -Name Start -Value 4 -PropertyType DWord -Force | Out-Null
    }
}

function Ensure-AppXSvcHardeningTask {
    [CmdletBinding()]
    param()

    Import-Module ScheduledTasks -ErrorAction SilentlyContinue | Out-Null

    $hardeningDir  = 'C:\ProgramData\AppXLock'
    $hardeningFile = Join-Path $hardeningDir 'Disable-AppXSvc.ps1'

    if (-not (Test-Path $hardeningDir)) {
        New-Item -ItemType Directory -Path $hardeningDir -Force | Out-Null
    }

    $hardeningScript = @'
param()
$ErrorActionPreference = "SilentlyContinue"
$svcName    = "AppXSvc"
$svcKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AppXSvc"
try {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        if ($svc.Status -ne "Stopped") { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
    }
    try { & sc.exe config $svcName start= disabled | Out-Null } catch { } finally { $global:LASTEXITCODE = 0 }
    if (Test-Path $svcKeyPath) {
        New-ItemProperty -Path $svcKeyPath -Name Start -Value 4 -PropertyType DWord -Force | Out-Null
    }
} catch { }
'@

    Set-Content -Path $hardeningFile -Value $hardeningScript -Encoding UTF8 -Force

    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$hardeningFile`""
    $trigger = New-ScheduledTaskTrigger -AtStartup

    $taskName = 'Hard-Disable-AppXSvc'
    $taskPath = '\Hardening\'

    try { Start-Service -Name Schedule -ErrorAction SilentlyContinue } catch { }

    # Retry registration (Task Scheduler can be flaky during bootstrap)
    $max = 5
    for ($i=1; $i -le $max; $i++) {
        try {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
            Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -RunLevel Highest -User 'SYSTEM' -Force | Out-Null
            return
        } catch {
            Write-Log -message ("Ensure-AppXSvcHardeningTask :: Register-ScheduledTask failed ({0}/{1}): {2}" -f $i,$max,$_.Exception.Message) -severity 'WARN'
            Start-Sleep -Seconds 3
            if ($i -eq $max) { throw }
        }
    }
}

function Test-AppXSvcDisabled {
    [CmdletBinding()]
    param()

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -eq $svc) { return $true }

    $regStart = $null
    try { $regStart = (Get-ItemProperty -Path $svcKeyPath -Name Start -ErrorAction SilentlyContinue).Start } catch { }
    $regDisabled = ($regStart -eq 4)

    $cimDisabled = $false
    try {
        $svcCim = Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
        if ($svcCim) { $cimDisabled = ($svcCim.StartMode -eq 'Disabled') }
    } catch { }

    if ($svc.Status -eq 'Stopped' -and ($regDisabled -or $cimDisabled)) { return $true }
    return $false
}

# --- Main ---------------------------------------------------------------
try {
    Write-Log -message 'disable_appxsvc :: begin' -severity 'DEBUG'

    Write-Log -message 'disable_appxsvc :: Disable-AppXSvcCore' -severity 'DEBUG'
    Disable-AppXSvcCore

    Write-Log -message 'disable_appxsvc :: Ensure-AppXSvcHardeningTask' -severity 'DEBUG'
    Ensure-AppXSvcHardeningTask

    # Re-apply after task registration
    Write-Log -message 'disable_appxsvc :: Disable-AppXSvcCore (post-task)' -severity 'DEBUG'
    Disable-AppXSvcCore

    # Verify with retries
    $max = 10
    for ($i = 1; $i -le $max; $i++) {
        if (Test-AppXSvcDisabled) { break }
        Write-Log -message ("disable_appxsvc :: waiting for AppXSvc to disable ({0}/{1})" -f $i, $max) -severity 'DEBUG'
        Start-Sleep -Seconds 2
        Disable-AppXSvcCore
    }

    if (-not (Test-AppXSvcDisabled)) {
        Write-Log -message 'disable_appxsvc :: AppXSvc is NOT disabled' -severity 'ERROR'
        exit 2
    }

    Write-Log -message 'disable_appxsvc :: complete (AppXSvc disabled)' -severity 'DEBUG'
    exit 0
}
catch {
    $msg = "disable_appxsvc :: FATAL: $($_.Exception.ToString())"
    try { Write-Output $msg } catch { }
    Write-Log -message $msg -severity 'ERROR'
    exit 1
}
