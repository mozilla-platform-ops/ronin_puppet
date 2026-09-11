# scripts\check_fleetbench_variance.ps1
# NSClient++ external check that surfaces fleetbench run-to-run VARIANCE to Marlin:
# the latest run compared to the node's FIRST recorded run (its initial baseline).
# Complements check_fleetbench.ps1 (which reports the absolute GOOD/BAD verdict).
# Reads the status file written by the maintain-system fleetbench check (RELOPS-2402):
#   C:\fleetbench\results\fleetbench_status.json
# Nagios contract: print one line "STATE - text | perfdata" and exit 0/1/2/3.

$ErrorActionPreference = 'Stop'

function Exit-With([int]$code, [string]$msg) {
    Write-Output $msg
    exit $code
}

$statusFile  = 'C:\fleetbench\results\fleetbench_status.json'
$maxAgeHours = 168   # status older than 7 days is considered stale

if (-not (Test-Path -LiteralPath $statusFile)) {
    Exit-With 3 "UNKNOWN - no fleetbench status yet (no benchmark has run)"
}

try {
    $s = Get-Content -LiteralPath $statusFile -Raw | ConvertFrom-Json
}
catch {
    Exit-With 3 "UNKNOWN - cannot read fleetbench status: $($_.Exception.Message)"
}

# No variance available (first run / unknown hardware / unparseable)
if ($null -eq $s.var_min_delta) {
    $why = if ($s.drift_note) { $s.drift_note } else { 'no_baseline' }
    Exit-With 3 "UNKNOWN - no variance data ($why)"
}

$dMin  = [double]$s.var_min_delta
$dMean = [double]$s.var_mean_delta
$dIter = [double]$s.var_iter_pct

$ageH = $null
try {
    $ageH = [math]::Round(((Get-Date).ToUniversalTime() - ([datetime]$s.timestamp_utc).ToUniversalTime()).TotalHours, 1)
}
catch { }

$driftCode = if ($s.drift) { 1 } else { 0 }
$ageVal = if ($null -ne $ageH) { $ageH } else { 0 }
# Deltas are (last - first); negative = degraded vs first run.
$perf = "variance_drift=$driftCode;1;;0;1 var_min_delta=$dMin var_mean_delta=$dMean var_iter_pct=$dIter age_h=$ageVal"

$summary = "vs first run ($($s.first_run)): min%base d=$dMin mean%base d=$dMean iters d=$dIter%"
if ($null -ne $ageH) { $summary += " age=${ageH}h" }

# Stale status -> WARN
if ($null -ne $ageH -and $ageH -gt $maxAgeHours) {
    Exit-With 1 "WARN - fleetbench variance status stale - $summary | $perf"
}

if ($s.drift) {
    Exit-With 1 "WARN - fleetbench variance drift - $summary | $perf"
}
Exit-With 0 "OK - fleetbench variance within range - $summary | $perf"
