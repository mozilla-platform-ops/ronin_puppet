# scripts\check_defender.ps1
# NSClient++ external check that asserts Windows Defender real-time / on-access
# scanning is effectively DISABLED on the datacenter hardware fleet.
#
# Why not Get-MpComputerStatus? On this fleet the Defender management provider
# fails to load ("Provider load failure") because the disable mechanism renames
# the Defender driver binaries (see win_disable_services::disable_windows_defender_schtask).
# So we assert the ground-truth signals instead:
#   - WdFilter (the file-system minifilter that performs on-access scanning) is
#     NOT running, AND its driver binary is renamed to WdFilter.sys.bak.
# Real-time scanning cannot occur without WdFilter loaded, regardless of whether
# the WinDefend service or MsMpEng process happen to be alive.
#
# The key risk this guards against: a Defender platform/signature update can
# restore WdFilter.sys and re-arm on-access scanning until the next boot (when
# the disable schtask re-renames it). That silently injects scan overhead into
# CI perf runs, so we surface it as CRITICAL.
#
# Nagios contract: print one line "STATE - text | perfdata" and exit 0/1/2/3.

$ErrorActionPreference = 'Stop'

function Exit-With([int]$code, [string]$msg) {
    Write-Output $msg
    exit $code
}

$driver    = "$env:SystemRoot\System32\drivers\WdFilter.sys"
$driverBak = "$env:SystemRoot\System32\drivers\WdFilter.sys.bak"

# 1) Is the on-access minifilter currently running?
$wdfState = 'unknown'
try {
    $q = (& "$env:SystemRoot\System32\sc.exe" query WdFilter 2>$null | Select-String 'STATE')
    if ($q -match 'RUNNING') { $wdfState = 'running' }
    elseif ($q -match 'STOPPED') { $wdfState = 'stopped' }
    elseif (-not $q) { $wdfState = 'absent' }
}
catch { $wdfState = 'unknown' }

# 2) Is the driver binary renamed (disabled) or restored (re-armed)?
$sysPresent = Test-Path -LiteralPath $driver
$bakPresent = Test-Path -LiteralPath $driverBak

# 3) WinDefend service state (informational only — not the deciding factor)
$winDefend = 'unknown'
try {
    $svc = Get-Service WinDefend -ErrorAction SilentlyContinue
    if ($svc) { $winDefend = "$($svc.Status)" } else { $winDefend = 'absent' }
}
catch { }

# Numeric health code for Grafana/InfluxDB: 0 disabled(OK) / 2 active(CRIT) / 3 unknown
$rtRunning = if ($wdfState -eq 'running' -or $sysPresent) { 1 } else { 0 }
$health    = switch ($wdfState) {
    'stopped' { if ($sysPresent) { 2 } else { 0 } }
    'absent'  { if ($sysPresent) { 2 } else { 0 } }
    'running' { 2 }
    default   { 3 }
}

$perf = "defender_rt_on=$rtRunning;1;1;0;1 health=$health;1;2;0;3"
$summary = "WdFilter=$wdfState WdFilter.sys=$(if($sysPresent){'PRESENT'}else{'renamed'}) bak=$(if($bakPresent){'yes'}else{'no'}) WinDefend=$winDefend"

if ($wdfState -eq 'unknown') {
    Exit-With 3 "UNKNOWN - cannot determine WdFilter state - $summary | $perf"
}

# Re-armed: the minifilter is running, or its binary was restored by an update.
if ($wdfState -eq 'running') {
    Exit-With 2 "CRITICAL - Defender on-access scanning is ACTIVE (WdFilter running) - $summary | $perf"
}
if ($sysPresent) {
    Exit-With 2 "CRITICAL - WdFilter.sys restored (likely Defender platform update); will re-arm at next boot - $summary | $perf"
}

# WdFilter stopped/absent and binary renamed => real-time effectively off.
Exit-With 0 "OK - Defender real-time scanning disabled (WdFilter not loaded) - $summary | $perf"
