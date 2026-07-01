# scripts\check_fleetbench.ps1
# NSClient++ external check that surfaces the latest fleetbench hardware-health
# verdict to Marlin (Icinga2). It does NOT run the benchmark — it reads the status
# file written by the maintain-system fleetbench check (RELOPS-2402):
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

# Age of the last run
$ageH = $null
try {
    $ageH = [math]::Round(((Get-Date).ToUniversalTime() - ([datetime]$s.timestamp_utc).ToUniversalTime()).TotalHours, 1)
}
catch { }

# Coerce metrics (may be null for UNKNOWN/unparseable)
$minPct  = if ($null -ne $s.min_pct)    { [double]$s.min_pct }    else { 0 }
$meanPct = if ($null -ne $s.mean_pct)   { [double]$s.mean_pct }   else { 0 }
$cv      = if ($null -ne $s.tput_cv)    { [double]$s.tput_cv }    else { 0 }
$iters   = if ($null -ne $s.iterations) { [int]$s.iterations }    else { 0 }

# Numeric health code for graphing in Grafana/InfluxDB
$health = switch ($s.verdict) { 'GOOD' { 0 } 'MARGINAL' { 1 } 'BAD' { 2 } default { 3 } }

$ageVal = if ($null -ne $ageH) { $ageH } else { 0 }
$perf = "health=$health;1;2;0;3 min_pct=$minPct;;;0;200 mean_pct=$meanPct;;;0;200 tput_cv=$cv;;;0;100 iters=$iters age_h=$ageVal"

$summary = "verdict=$($s.verdict) hw=$($s.hw_type) min%base=$([math]::Round($minPct)) mean%base=$([math]::Round($meanPct)) tputCV=$([math]::Round($cv))% iters=$iters"
if ($s.drift) { $summary += " DROP-OFF($($s.drift_note))" }
if ($null -ne $ageH) { $summary += " age=${ageH}h" }

# Stale status -> WARN regardless of last verdict
if ($null -ne $ageH -and $ageH -gt $maxAgeHours) {
    Exit-With 1 "WARN - fleetbench status stale - $summary | $perf"
}

switch ($s.verdict) {
    'GOOD' {
        if ($s.drift) { Exit-With 1 "WARN - $summary | $perf" }
        else { Exit-With 0 "OK - $summary | $perf" }
    }
    'MARGINAL'    { Exit-With 1 "WARN - $summary | $perf" }
    'BAD'         { Exit-With 2 "CRITICAL - $summary | $perf" }
    default       { Exit-With 3 "UNKNOWN - $summary | $perf" }
}
